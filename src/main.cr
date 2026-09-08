require "./lib"

schedule  = Tracks::Scheduled.new
scheduled = schedule.get_scheduled

trains = Tracks::Live.fetch_live(scheduled)

alerts = Tracks::Alerts.fetch_alerts

index = HTTP::Client.get("https://www.caltrain.com").body
holiday = HTTP::Client.get("https://www.caltrain.com/schedules/holiday-service-schedules").body

# every 60 secs
spawn do
  loop do
    sleep 60.seconds

    begin
      scheduled = schedule.get_scheduled
      trains = Tracks::Live.fetch_live(scheduled)
    rescue err
    end
  end
end

# every 180 secs
spawn do
  loop do
    sleep 180.seconds

    begin
      alerts = Tracks::Alerts.fetch_alerts
    rescue err
    end
  end
end

# every 3am
spawn do
  loop do
    loc = Time::Location.load("America/Los_Angeles")
    now = Time.local(loc)

    next_run = Time.local(now.year, now.month, now.day, 3, 0, 0, location: loc)

    if now >= next_run
      date = now + 1.day
      next_run = Time.local(date.year, date.month, date.day, 3, 0, 0, location: loc)
    end

    sleep next_run - now

    begin
      schedule = Tracks::Scheduled.new
      scheduled = schedule.get_scheduled
    rescue err
    end

    begin
      index = HTTP::Client.get("https://www.caltrain.com").body
    rescue err
    end

    begin
      holiday = HTTP::Client.get("https://www.caltrain.com/schedules/holiday-service-schedules").body
    rescue err
    end
  end
end

before_all do |env|
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.headers["Access-Control-Allow-Headers"] = "Authorization"

  next if env.request.method == "OPTIONS"

  auth = env.request.headers["Authorization"]?
  raise "Client unauthorized" if auth != ENV["AUTH"]
end

options "/*" do |env|
  ""
end

get "/trains" do |env|
  env.response.content_type = "application/json"
  trains.to_json
end

get "/alerts" do |env|
  env.response.content_type = "application/json"
  alerts.to_json
end

get "/caltrain/index" do |env|
  env.response.content_type = "text/html; charset=UTF-8"
  index
end

get "/caltrain/holiday" do |env|
  env.response.content_type = "text/html; charset=UTF-8"
  holiday
end

Kemal.config.env = "production"
Kemal.run
