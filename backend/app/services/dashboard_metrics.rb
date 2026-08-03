# DashboardMetrics computes the high-level numbers shown on the mission-control
# dashboard. It is intentionally read-only and cheap to call: every value is a
# single aggregated query or a small scoped count. The numbers are broadcast via
# DashboardEventService so the dashboard updates in real time.
class DashboardMetrics
  class << self
    def call
      new.call
    end
  end

  def call
    {
      total_projects: Project.count,
      running_test_runs: running_test_runs,
      queued_jobs: queued_jobs,
      running_jobs: running_jobs,
      completed_jobs: completed_jobs,
      failed_jobs: failed_jobs,
      active_workers: active_workers,
      idle_workers: idle_workers,
      offline_workers: offline_workers,
      average_execution_time: average_execution_time,
      average_queue_wait_time: average_queue_wait_time,
      worker_utilization: worker_utilization,
      success_rate: success_rate,
      updated_at: Time.current.iso8601
    }
  end

  private

  def running_test_runs
    TestRun.where(status: %w[running scheduling]).count
  end

  def queued_jobs
    Job.where(status: %w[queued retrying]).count
  end

  def running_jobs
    Job.where(status: %w[running uploading_artifacts]).count
  end

  def completed_jobs
    Job.completed.count
  end

  def failed_jobs
    Job.failed.count
  end

  def active_workers
    WorkerHeartbeat.where.not(status: :offline).count
  end

  def idle_workers
    WorkerHeartbeat.idle.count
  end

  def offline_workers
    WorkerHeartbeat.offline.count
  end

  def average_execution_time
    avg = Job.where.not(duration_ms: nil).average(:duration_ms)
    avg && (avg / 1000.0).round(2)
  end

  def average_queue_wait_time
    # Average seconds between job creation and the moment it started running.
    jobs = Job.where.not(started_at: nil)
    return 0.0 if jobs.none?

    total_seconds = jobs.sum("EXTRACT(EPOCH FROM (started_at - created_at))")
    (total_seconds / jobs.count).round(2)
  end

  def worker_utilization
    total = WorkerHeartbeat.count
    return 0.0 if total.zero?

    busy = WorkerHeartbeat.busy.count
    ((busy.to_f / total) * 100).round(1)
  end

  def success_rate
    completed = Job.completed.count
    failed = Job.failed.count
    total = completed + failed
    return 100.0 if total.zero?

    ((completed.to_f / total) * 100).round(1)
  end
end
