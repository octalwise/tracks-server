require "./lib"

# get scheduled trains
schedule  = Tracks::Scheduled.new
scheduled = schedule.get_scheduled

# fetch live trains
trains = Tracks::Live.fetch_live(scheduled)

# fetch alerts
alerts = Tracks::Alerts.fetch_alerts

# every 90 secs
spawn do
  loop do
    sleep 90

    begin
      # get scheduled trains
      scheduled = schedule.get_scheduled

      # fetch live trains
      trains = Tracks::Live.fetch_live(scheduled)
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
      alerts = Tracks::Alerts.fetch_alerts
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
      schedule = Tracks::Scheduled.new
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
