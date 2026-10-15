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

      def to_normal(scheduled : Tracks::Train, old : Tracks::Train?) : Tracks::Train
        stops = @stops.map do |stop|
          sched_stop = scheduled.stops.find { |sched| sched.station == stop.station }.not_nil!
          stop.to_normal(sched_stop)
        end

        now = Time.local(Time::Location.load("America/Los_Angeles"))
        delay = Time::Span.zero

        all_stops = scheduled.stops.sort_by(&.scheduled).map do |sched|
          found = stops.find { |stop| stop.station == sched.station }
          old_stop = old.try &.stops.find { |stop| stop.station == sched.station && stop.expected <= now }

          stop = found || old_stop ||
            Tracks::Stop.new(sched.station, sched.scheduled, sched.scheduled + delay)

          delay = stop.expected - stop.scheduled
          stop
        end

        direction = @trip.direction == 0 ? "N" : "S"

        location, offset = get_location(direction, all_stops)

        local = @trip.route == "Local Weekday" || @trip.route == "Local Weekend"
        route = local ? "Local" : @trip.route

        Tracks::Train.new(
          @trip.id,
          true,
          direction,
          route,
          location,
          offset,
          all_stops,
        )
      end

      def get_location(direction : String, stops : Array(Tracks::Stop)) : {Int32?, Bool}
        now = Time.local(Time::Location.load("America/Los_Angeles"))

        return {nil, false} if stops.first.expected > now || stops.last.expected <= now

        next_idx = stops.index! { |s| s.expected > now }

        next_stop = stops[next_idx]
        prev_stop = stops[next_idx - 1]

        idx1 = Tracks::STATIONS.index { |s| s.contains(prev_stop.station) }.not_nil!
        idx2 = Tracks::STATIONS.index { |s| s.contains(next_stop.station) }.not_nil!

        if now >= next_stop.expected - 20.seconds
          {Tracks::STATIONS[idx2].side(direction), false}
        else
          dt = next_stop.expected - prev_stop.expected
          mix = ((now - prev_stop.expected) / dt).clamp(0, 1)

          offset = mix * (idx2 - idx1)
          frac = offset - offset.trunc

          {Tracks::STATIONS[idx1 + offset.to_i].side(direction), frac.abs > 0.25}
        end
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

    def self.fetch_live(
      scheduled : Array(Tracks::Train),
      old : Array(Tracks::Train) = [] of Tracks::Train
    ) : Array(Tracks::Train)
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

      res = client.get(url.to_s).body

      Data.from_json(res)
        .vehicles
        .map(&.trip_update)
        .map do |update|
          sched = scheduled.find { |train| train.id == update.trip.id }
          old_train = old.find { |train| train.id == update.trip.id }

          update.to_normal(sched, old_train) if sched
        end
        .compact
    end
  end
end
