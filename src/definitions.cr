module Tracks
  class Train
    include JSON::Serializable

    getter id : Int32
    getter live : Bool
    getter direction : String
    getter route : String

    @[JSON::Field(emit_null: true)]
    getter location : Int32?

    getter stops : Array(Stop)

    def initialize(@id, @live, @direction, @route, @location, @stops)
    end
  end

  class Stop
    include JSON::Serializable

    getter station : Int32

    @[JSON::Field(converter: Time::EpochConverter)]
    getter scheduled : Time

    @[JSON::Field(converter: Time::EpochConverter)]
    getter expected : Time

    def initialize(@station, @scheduled, @expected)
    end
  end

  class Alert
    include JSON::Serializable

    getter header : String

    @[JSON::Field(emit_null: true)]
    getter description : String?

    def initialize(@header, @description)
    end
  end
end
