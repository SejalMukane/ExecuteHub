require "sidekiq/api"

# QueueDashboard aggregates the state of the "test_execution" queue for the
# /queue API. Queued and running counts come from Sidekiq itself; completed and
# failed counts come from the jobs table (terminal states are not retained in
# the queue after processing).
class QueueDashboard
  QUEUE_NAME = "test_execution"

  def self.call
    new.call
  end

  def call
    {
      queued_jobs: Sidekiq::Queue.new(QUEUE_NAME).size,
      running_jobs: running_jobs,
      completed_jobs: Job.completed.count,
      failed_jobs: Job.failed.count
    }
  end

  private

  # Number of Sidekiq processes currently executing a test_execution job.
  def running_jobs
    Sidekiq::WorkSet.new.count { |_process, _thread, work| work["queue"] == QUEUE_NAME }
  end
end
