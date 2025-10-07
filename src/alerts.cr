module Tracks
  module Alerts
    class Alert
      include JSON::Serializable

      @[JSON::Field(key: "Alert")]
      getter alert : AlertInfo
    end

    class AlertInfo
      include JSON::Serializable

      @[JSON::Field(key: "HeaderText", root: "Translation")]
      getter header_text : Array(Info)

      @[JSON::Field(key: "DescriptionText", root: "Translation")]
      getter description_text : Array(Info)

      def to_normal : Tracks::Alert
        header =
          @header_text
            .find { |info| info.language == "en" }
            .not_nil!
            .text
            .strip

        description =
          @description_text
            .find { |info| info.language == "en" }
            .not_nil!
            .text
            .strip

        if !header.empty?
          Tracks::Alert.new(header, description)
        else
          Tracks::Alert.new(description, nil)
        end
      end
    end

    class Info
      include JSON::Serializable

      @[JSON::Field(key: "Text")]
      getter text : String

      @[JSON::Field(key: "Language")]
      getter language : String
    end

    def self.fetch_alerts : Array(Tracks::Alert)
      res = HTTP::Client.get(
        "https://www.caltrain.com/gtfs/api/v1/servicealerts/3655"
      ).body

      Array(Alert)
        .from_json(res)
        .map(&.alert)
        .map(&.to_normal)
    end
  end
end
