# Streams worker pool events (heartbeats, online/offline transitions).
# The shared "workers" stream is used so every dashboard sees the same pool state.
class WorkerChannel < ApplicationCable::Channel
  def subscribed
    stream_from "workers"
  end
end
