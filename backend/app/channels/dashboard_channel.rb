# Streams global dashboard events: overview metrics, activity, and alerts.
# Every authenticated client on the mission-control dashboard subscribes here.
class DashboardChannel < ApplicationCable::Channel
  def subscribed
    stream_from "dashboard"
  end
end
