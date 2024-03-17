require "./lib"

# fetch scheduled trains
schedule  = Tracks::Data::Scheduled.new
scheduled = schedule.fetch_trains

# fetch realtime trains
trains    = Tracks::Data::Realtime.fetch_realtime(scheduled)
train_ids = trains.map(&.id)

# fetch alerts
alerts = Tracks::Data::Alerts.fetch_alerts

# every 90 secs
spawn do
  loop do
    sleep 90

    # fetch scheduled trains
    scheduled = schedule.fetch_trains

    # fetch realtime trains
    trains    = Tracks::Data::Realtime.fetch_realtime(scheduled)
    train_ids = trains.map(&.id)
  end
end

# every 180 secs
spawn do
  loop do
    sleep 180

    # fetch alerts
    alerts = Tracks::Data::Alerts.fetch_alerts
  end
end

# every 24 hours
spawn do
  loop do
    sleep 86_400

    # update scheduled doc
    schedule = Tracks::Data::Scheduled.new
  end
end

before_all do |env|
  # json content type
  env.response.content_type = "application/json"
end

# realtime trains
get "/trains" do
  trains.to_json
end

# alerts
get "/alerts" do
  alerts.to_json
end

# run server
Kemal.run
