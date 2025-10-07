require "./lib"

schedule  = Tracks::Scheduled.new
scheduled = schedule.get_scheduled

trains = Tracks::Live.fetch_live(scheduled)

alerts = Tracks::Alerts.fetch_alerts

# every 90 secs
spawn do
  loop do
    sleep 90

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
    sleep 180

    begin
      alerts = Tracks::Alerts.fetch_alerts
    rescue err
    end
  end
end

# every 5am
spawn do
  loop do
    loc = Time::Location.load("America/Los_Angeles")
    now = Time.local(loc)

    next_run = Time.local(now.year, now.month, now.day, 5, 1, 0, location: loc)

    if now >= next_run
      date = now + 1.day
      next_run = Time.local(date.year, date.month, date.day, 5, 1, 0, location: loc)
    end

    sleep next_run - now

    begin
      schedule = Tracks::Scheduled.new
    rescue err
    end
  end
end

before_all do |env|
  env.response.content_type = "application/json"

  auth = env.request.headers["Authorization"]?
  raise "Client unauthorized" if auth != ENV["AUTH"]
end

get "/trains" do
  trains.to_json
end

get "/alerts" do
  alerts.to_json
end

Kemal.config.env = "production"
Kemal.run
