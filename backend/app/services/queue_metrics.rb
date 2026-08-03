require "sidekiq/api"

# QueueMetrics exposes the current state of the test_execution queue plus
# historical counters for the day. It is used by DashboardEventService to push
# live queue updates to the QueueChannel and dashboard.
class QueueMetrics
  QUEUE_NAME = "test_execution".freeze

  class << self
    def call
      new.call
    end
  end

  def call
    {
      queue_size: queue_size,
      running_jobs: running_jobs,
      average_wait_time: average_wait_time,
      longest_waiting_job: longest_waiting_job,
      completed_today: completed_today,
      failed_today: failed_today,
      retry_count: retry_count,
      updated_at: Time.current.iso8601
    }
  end

  private

  def queue_size
    Sidekiq::Queue.new(QUEUE_NAME).size
  end

  def running_jobs
    Sidekiq::WorkSet.new.count { |_process, _thread, work| work["queue"] == QUEUE_NAME }
  end

  def average_wait_time
    oldest = Sidekiq::Queue.new(QUEUE_NAME).map { |job| Time.at(job.enqueued_at) }.min
    return 0.0 unless oldest

    (Time.current - oldest).round(2)
  end

  def longest_waiting_job
    oldest = Sidekiq::Queue.new(QUEUE_NAME).min_by { |job| job.enqueued_at }
    return nil unless oldest

    {
      job_id: oldest.args.first,
      enqueued_at: Time.at(oldest.enqueued_at).iso8601,
      waiting_seconds: (Time.current - Time.at(oldest.enqueued_at)).round(2)
    }
  end

  def completed_today
    Job.completed.where("finished_at >= ?", Time.current.beginning_of_day).count
  end

  def failed_today
    Job.failed.where("finished_at >= ?", Time.current.beginning_of_day).count
  end

  def retry_count
    Job.where("retry_count > 0").count
  end
end
