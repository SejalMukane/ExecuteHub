# Streams queue-level events: queue depth, running jobs, completed/failed counts,
# and retry activity. One shared stream for all queue dashboards.
class QueueChannel < ApplicationCable::Channel
  def subscribed
    stream_from "queue"
  end
end
