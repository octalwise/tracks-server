module Tracks
  class Scheduled
    @trains : Array(ScheduledTrain)
    @stops  : Array(ScheduledStop)

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

              # previous day
              if now.hour <= 4 && stop.time.hour >= 4
                stop.time -= 1.days
              end

              # next day
              if now.hour >= 4 && stop.time.hour < 4
                stop.time += 1.days
              end
            end
          end

      @trains.map do |train|
        train_stops =
          stops.select { |stop| stop.train == train.id }

        first, last = train_stops.map(&.time).minmax

        location =
          if first <= now && last >= now
            stop =
              train_stops
                .sort { |a, b| b.time <=> a.time }
                .find { |stop| stop.time <= now }

            if stop
              stop.station
            end
          end

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
  end
end
