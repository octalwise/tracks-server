module Tracks
  # train
  class Train
    include JSON::Serializable

    # train id
    getter id : Int32

    # is live
    getter live : Bool

    # direction
    getter direction : String

    # route
    getter route : String

    # current location
    @[JSON::Field(emit_null: true)]
    getter location : Int32?

    # all stops
    getter stops : Array(Stop)

    def initialize(@id, @live, @direction, @route, @location, @stops)
    end
  end

  # stop
  class Stop
    include JSON::Serializable

    # station id
    getter station : Int32

    # scheduled time
    @[JSON::Field(converter: Time::EpochConverter)]
    getter scheduled : Time

    # expected time
    @[JSON::Field(converter: Time::EpochConverter)]
    getter expected : Time

    def initialize(@station, @scheduled, @expected)
    end
  end

  # alert
  class Alert
    include JSON::Serializable

    # header text
    getter header : String

    # optional description
    getter description : String?

    def initialize(@header, @description)
    end
  end
end
