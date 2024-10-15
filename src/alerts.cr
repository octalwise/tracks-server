module Tracks
  # alerts
  module Alerts
    class Alert
      include JSON::Serializable

      @[JSON::Field(key: "Alert")]
      property alert : AlertInfo
    end

    class AlertInfo
      include JSON::Serializable

      @[JSON::Field(key: "HeaderText", root: "Translation")]
      property header_text : Array(Info)

      @[JSON::Field(key: "DescriptionText", root: "Translation")]
      property description_text : Array(Info)

      def to_normal : Tracks::Alert
        # english header
        header =
          @header_text
            .find { |info| info.language == "en" }
            .not_nil!
            .text
            .strip

        # english description
        description =
          @description_text
            .find { |info| info.language == "en" }
            .not_nil!
            .text
            .strip

        if !header.empty?
          # header and description
          Tracks::Alert.new(header, description)
        else
          # only description
          Tracks::Alert.new(description, nil)
        end
      end
    end

    class Info
      include JSON::Serializable

      @[JSON::Field(key: "Text")]
      property text : String

      @[JSON::Field(key: "Language")]
      property language : String
    end

    # fetch alerts from api
    def self.fetch_alerts : Array(Tracks::Alert)
      # fetch data
      res = HTTP::Client.get(
        "https://www.caltrain.com/gtfs/api/v1/servicealerts/3655"
      ).body

      # convert data
      Array(Alert)
        .from_json(res)
        .map(&.alert)
        .map(&.to_normal)
    end
  end
end
