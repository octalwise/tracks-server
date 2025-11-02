module Tracks
  module Live
    class Data
      include JSON::Serializable

      @[JSON::Field(key: "Entities")]
      getter vehicles : Array(Vehicle)
    end

    class Vehicle
      include JSON::Serializable

      @[JSON::Field(key: "TripUpdate")]
      getter trip_update : TripUpdate
    end

    class TripUpdate
      include JSON::Serializable

      @[JSON::Field(key: "Trip")]
      getter trip : Trip

      @[JSON::Field(key: "StopTimeUpdates")]
      getter stops : Array(Stop)

      def to_normal(scheduled : Tracks::Train) : Tracks::Train
        stops = @stops.map do |stop|
          scheduled_stop =
            scheduled
              .stops
              .find do |scheduled_stop|
                scheduled_stop.station == stop.station
              end
              .not_nil!

          stop.to_normal(scheduled_stop)
        end

        sched_last = scheduled.stops.last
        live_last = stops.last

        if sched_last.station != live_last.station
          stops.push(
            Tracks::Stop.new(
              sched_last.station,
              sched_last.scheduled,
              sched_last.scheduled + (live_last.expected - live_last.scheduled)
            )
          )
        end

        first_index =
          scheduled
            .stops
            .map(&.station)
            .index(@stops.first.station)
            .not_nil!

        index = [first_index - 1, 0].max
        stop = scheduled.stops[index]

        now = Time.local(Time::Location.load("America/Los_Angeles"))
        location = stop.expected <= now ? stop.station : nil

        local = @trip.route == "Local Weekday" || @trip.route == "Local Weekend"
        route = local ? "Local" : @trip.route

        Tracks::Train.new(
          @trip.id,
          true,
          @trip.direction == 0 ? "N" : "S",
          route,
          location,
          index != 0 ? scheduled.stops[..index] + stops : stops
        )
      end
    end

    class Trip
      include JSON::Serializable

      @[JSON::Field(key: "TripId", converter: Tracks::Live::IntConverter)]
      getter id : Int32

      @[JSON::Field(key: "RouteId")]
      getter route : String

      @[JSON::Field(key: "DirectionId")]
      getter direction : Int32
    end

    class Stop
      include JSON::Serializable

      @[JSON::Field(key: "StopId", converter: Tracks::Live::IntConverter)]
      getter station : Int32

      @[JSON::Field(key: "Arrival", root: "Time", converter: Time::EpochConverter)]
      getter arrival : Time?

      @[JSON::Field(key: "Departure", root: "Time", converter: Time::EpochConverter)]
      getter departure : Time?

      def to_normal(scheduled : Tracks::Stop) : Tracks::Stop
        Tracks::Stop.new(
          @station,
          scheduled.scheduled,
          (@departure || @arrival).not_nil!
        )
      end
    end

    class IntConverter
      def self.from_json(pull : JSON::PullParser) : Int32
        pull.read_string.to_i
      end
    end

    def self.fetch_live(scheduled : Array(Tracks::Train)) : Array(Tracks::Train)
      params = URI::Params.encode({
        api_key: ENV["API_KEY"],
        agency: "CT",
        format: "json"
      })

      url = URI.new(
        "https", "api.511.org",
        path: "transit/tripupdates",
        query: params
      )

      client = HTTP::Client.new(url)
      client.compress = true

      res = client.get(url.to_s).body[1..-1]

      Data.from_json(res)
        .vehicles
        .map(&.trip_update)
        .map do |update|
          train = scheduled.find do |train|
            train.id == update.trip.id
          end

          if train
            update.to_normal(train)
          end
        end
        .compact
    end
  end
end
