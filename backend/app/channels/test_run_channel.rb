# Streams events for a single TestRun (progress snapshots, job lifecycle, completion).
# Clients subscribe with the run id in the identifier: { channel: "TestRunChannel", id: 123 }.
class TestRunChannel < ApplicationCable::Channel
  def subscribed
    stream_from "test_run_#{params[:id]}"
  end
end
