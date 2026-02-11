module Tracks
  class Scheduled
    @trains : Array(ScheduledTrain)
    @stops : Array(ScheduledStop)

    class ScheduledTrain
      getter id : Int32
      getter direction : String
      getter route : String

      def initialize(@id, @direction, @route)
      end
    end

    class ScheduledStop
      getter station : Int32
      property time : Time
      getter train : Int32

      def initialize(@station, @time, @train)
      end
    end

    def initialize
      @trains = [] of ScheduledTrain
      @stops = [] of ScheduledStop

      html = HTTP::Client.get("https://www.caltrain.com").body

      document = Lexbor::Parser.new(html)

      document.css("table.caltrain_schedule tbody").each do |table|
        direction = table.parent.not_nil!["data-direction"] == "northbound" ? "N" : "S"

        table.css(
          "tr:first-child td.schedule-trip-header"
        ).each do |header|
          train = header["data-trip-id"].to_i

          route = header["data-route-id"]
          route = "Local" if route == "Local Weekday" || route == "Local Weekend"

          @trains << ScheduledTrain.new(train, direction, route)
        end

        table.css("tr[data-stop-id]").flat_map do |row|
          stop = row["data-stop-id"].to_i

          row.css("td.timepoint").map do |timepoint|
            next if timepoint.inner_text == "--"

            time = Time.parse(
              timepoint.inner_text,
              "%I:%M%p",
              Time::Location.load("America/Los_Angeles")
            )

            train = timepoint["data-trip-id"].to_i

            @stops << ScheduledStop.new(stop, time, train)
          end
        end
      end
    end

    def get_scheduled : Array(Train)
      now = Time.local(Time::Location.load("America/Los_Angeles"))

      stops =
        @stops
          .map do |stop|
            stop.tap do |stop|
              stop.time =
                Time.local(
                  now.year,
                  now.month,
                  now.day,
                  stop.time.hour,
                  stop.time.minute,
                  location: Time::Location.load("America/Los_Angeles")
                )

              cutoff = 3

              if now.hour < cutoff && stop.time.hour >= cutoff
                stop.time -= 1.days
              elsif now.hour >= cutoff && stop.time.hour < cutoff
                stop.time += 1.days
              end
            end
          end

      @trains.map do |train|
        train_stops = stops.select { |stop| stop.train == train.id }
        location = get_location(train.direction, train_stops)

        Train.new(
          train.id,
          false,
          train.direction,
          train.route,
          location,
          train_stops.map do |stop|
            Stop.new(stop.station, stop.time, stop.time)
          end
        )
      end
    end

    def get_location(direction : String, stops : Array(ScheduledStop)) : Int32?
      now = Time.local(Time::Location.load("America/Los_Angeles"))

      stops = stops.sort { |a, b| a.time <=> b.time }
      first, last = stops.map(&.time).minmax

      if first > now || last < now
        return nil
      end

      next_stop = stops.find { |s| s.time > now }.not_nil!

      next_idx =
        stops
          .map(&.station)
          .index(next_stop.station)
          .not_nil!

      prev_idx = next_idx > 0 ? next_idx - 1 : 0
      prev_stop = stops[prev_idx]

      idx1 = Tracks::STATIONS.index { |s| s.contains(prev_stop.station) }.not_nil!
      idx2 = Tracks::STATIONS.index { |s| s.contains(next_stop.station) }.not_nil!

      station =
        if prev_stop.time > now
          nil
        elsif idx1 == idx2
          Tracks::STATIONS[idx1]
        elsif idx2 == Tracks::STATIONS.size - 1 && now > next_stop.time + 20.seconds
          nil
        elsif now >= next_stop.time - 20.seconds
          Tracks::STATIONS[idx2]
        else
          dt = next_stop.time - prev_stop.time
          mix = dt.zero? ? 0.0 : (now - prev_stop.time) / dt

          offset = (mix.clamp(0, 1) * (idx2 - idx1)).floor.to_i
          Tracks::STATIONS[offset + idx1]
        end

      station.try &.side(direction)
    end
  end
end
