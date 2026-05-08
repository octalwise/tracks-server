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
          sched_stop =
            scheduled
              .stops
              .find { |sched| sched.station == stop.station }
              .not_nil!

          stop.to_normal(sched_stop)
        end

        sched_last = scheduled.stops.last
        live_last = stops.last

        if sched_last.station != live_last.station
          # add missing last station
          stops.push(
            Tracks::Stop.new(
              sched_last.station,
              sched_last.scheduled,
              sched_last.scheduled + (live_last.expected - live_last.scheduled)
            )
          )
        end

        next_stop = stops.first
        next_idx =
          scheduled
            .stops
            .map(&.station)
            .index(next_stop.station)
            .not_nil!

        prev_idx = next_idx > 0 ? next_idx - 1 : 0
        prev_stop = scheduled.stops[prev_idx]

        idx1 = Tracks::STATIONS.index { |s| s.contains(prev_stop.station) }.not_nil!
        idx2 = Tracks::STATIONS.index { |s| s.contains(next_stop.station) }.not_nil!

        now = Time.local(Time::Location.load("America/Los_Angeles"))

        location =
          if prev_stop.expected > now
            nil
          elsif idx1 == idx2
            Tracks::STATIONS[idx1]
          elsif idx2 == Tracks::STATIONS.size - 1 && now > next_stop.expected + 20.seconds
            nil
          elsif now >= next_stop.expected - 20.seconds
            Tracks::STATIONS[idx2]
          else
            dt = next_stop.expected - prev_stop.expected
            mix = dt.zero? ? 0.0 : (now - prev_stop.expected) / dt

            # mix location
            offset = (mix.clamp(0, 1) * (idx2 - idx1)).floor.to_i
            Tracks::STATIONS[offset + idx1]
          end

        local = @trip.route == "Local Weekday" || @trip.route == "Local Weekend"
        route = local ? "Local" : @trip.route

        direction = @trip.direction == 0 ? "N" : "S"

        Tracks::Train.new(
          @trip.id,
          true,
          direction,
          route,
          location.try &.side(direction),
          scheduled.stops.map do |sched|
            stop = stops.find { |stop| stop.station == sched.station }
            stop || sched
          end
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
          train = scheduled.find { |train| train.id == update.trip.id }

          if train
            update.to_normal(train)
          end
        end
        .compact
    end
  end
end
