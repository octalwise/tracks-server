module Tracks
  # train
  class Train
    include JSON::Serializable

    # train id
    property id : Int32

    # is live
    property live : Bool

    # direction
    property direction : String

    # line
    property line : String

    # current location
    @[JSON::Field(emit_null: true)]
    property location : Int32?

    # all stops
    property stops : Array(Stop)

    def initialize(@id, @live, @direction, @line, @location, @stops)
    end
  end

  # stop
  class Stop
    include JSON::Serializable

    # station id
    property station : Int32

    # scheduled time
    @[JSON::Field(converter: Time::EpochConverter)]
    property scheduled : Time

    # expected time
    @[JSON::Field(converter: Time::EpochConverter)]
    property expected : Time

    def initialize(@station, @scheduled, @expected)
    end
  end

  # alert
  class Alert
    include JSON::Serializable

    # header text
    property header : String

    # optional description
    property description : String?

    def initialize(@header, @description)
    end
  end
end
