module Tracks
  class Train
    include JSON::Serializable

    getter id : Int32
    getter live : Bool

    getter direction : String
    getter route : String
    getter service : String

    @[JSON::Field(emit_null: true)]
    getter location : Int32?

    getter stops : Array(Stop)

    def initialize(@id, @live, @direction, @route, @location, @stops)
      @service = "normal"
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

  STATIONS = Array(Station).from_json({{ read_file("src/stations.json") }})

  class Station
    include JSON::Serializable

    getter north : Int32
    getter south : Int32
    getter name : String

    def contains(id : Int32) : Bool
      @north == id || @south == id
    end

    def side(direction : String) : Int32
      direction == "N" ? @north : @south
    end
  end
end
