# Live stream for a single TestRun: progress snapshots and job lifecycle
# events for that run. Clients subscribe with the run id in the identifier.
class TestRunsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "test_run_#{params[:id]}"
  end
end
