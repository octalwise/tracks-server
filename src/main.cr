require "./lib"

# fetch scheduled trains
schedule  = Tracks::Data::Scheduled.new
scheduled = schedule.fetch_trains

# fetch live trains
trains = Tracks::Data::Live.fetch_live(scheduled)

# fetch alerts
alerts = Tracks::Data::Alerts.fetch_alerts

# every 90 secs
spawn do
  loop do
    sleep 90

    begin
      # fetch scheduled trains
      scheduled = schedule.fetch_trains

      # fetch live trains
      trains = Tracks::Data::Live.fetch_live(scheduled)
    rescue
    end
  end
end

# every 180 secs
spawn do
  loop do
    sleep 180

    begin
      # fetch alerts
      alerts = Tracks::Data::Alerts.fetch_alerts
    rescue
    end
  end
end

# every 24 hours
spawn do
  loop do
    sleep 86_400

    begin
      # update scheduled doc
      schedule = Tracks::Data::Scheduled.new
    rescue
    end
  end
end

before_all do |env|
  # json content type
  env.response.content_type = "application/json"

  # require auth token
  auth = env.request.headers["Authorization"]?
  raise "Client unauthorized" if auth != ENV["AUTH"]
end

# live trains
get "/trains" do
  trains.to_json
end

# alerts
get "/alerts" do
  alerts.to_json
end

# production env
Kemal.config.env = "production"

# run server
Kemal.run
