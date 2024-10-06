module Tracks
  module Data
    # scheduled trains
    class Scheduled
      property trains : Array(ScheduledTrain)
      property stops  : Array(ScheduledStop)

      # scheduled train
      class ScheduledTrain
        property id        : Int32
        property direction : String
        property route     : String

        def initialize(@id, @direction, @route)
        end
      end

      # scheduled train stop
      class ScheduledStop
        property station : Int32
        property time    : Time
        property train   : Int32

        def initialize(@station, @time, @train)
        end
      end

      # initialize scheduler
      def initialize
        @trains = [] of ScheduledTrain
        @stops  = [] of ScheduledStop

        # fetch data
        html = HTTP::Client.get("https://www.caltrain.com").body

        # document parser
        document = Lexbor::Parser.new(html)

        now = Time.local(Time::Location.fixed(-3600 * 7))
        day_type = now.saturday? || now.sunday? ? "weekend" : "weekday"

        document.css("table.caltrain_schedule tbody").each do |table|
          direction = table.parent.not_nil!["data-direction"] == "northbound" ? "N" : "S"

          # scheduled trains
          table.css(
            "tr:first-child td.schedule-trip-header[data-service-type=#{day_type}]"
          ).each do |header|
            train = header["data-trip-id"].to_i
            route = header["data-route-id"]

            # add scheduled train
            @trains << ScheduledTrain.new(train, direction, route)
          end

          # scheduled stops
          table.css("tr[data-stop-id]").flat_map do |row|
            stop = row["data-stop-id"].to_i

            row.css("td.timepoint").map do |timepoint|
              next if timepoint.inner_text == "--"

              time = Time.parse(
                timepoint.inner_text,
                "%I:%M%p",
                Time::Location.fixed(-3600 * 7)
              )

              train = timepoint["data-trip-id"].to_i

              # add scheduled stop
              @stops << ScheduledStop.new(stop, time, train)
            end
          end
        end
      end

      # fetch scheduled trains
      def fetch_trains : Array(Train)
        now = Time.local(Time::Location.fixed(-3600 * 7))

        stops =
          @stops
            .map do |stop|
              stop.tap do |stop|
                # stop time
                stop.time =
                  Time.local(
                    now.year,
                    now.month,
                    now.day,
                    stop.time.hour,
                    stop.time.minute,
                    location: Time::Location.fixed(-3600 * 7)
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

          # find location
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

          # create train
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
end
