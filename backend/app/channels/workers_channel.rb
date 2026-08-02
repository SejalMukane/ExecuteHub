# Live stream for the whole worker pool: heartbeats, offline/online transitions.
# Any authenticated client subscribes to every worker event on the shared
# "workers" stream.
class WorkersChannel < ApplicationCable::Channel
  def subscribed
    stream_from "workers"
  end
end
