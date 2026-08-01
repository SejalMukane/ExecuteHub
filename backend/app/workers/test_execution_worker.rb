# TestExecutionWorker picks a Job up off the "test_execution" queue and hands
# it to WorkerExecutor, which runs the real Playwright execution inside a
# Docker container and owns the Job's lifecycle (running -> uploading_artifacts
# -> completed/failed).
#
# This worker contains no Docker or Playwright logic itself — WorkerExecutor
# is kept Sidekiq-free and reusable, and this class is only the Sidekiq bridge.
class TestExecutionWorker
  include Sidekiq::Worker

  sidekiq_options queue: "test_execution", retry: 3, backtrace: true

  def perform(job_id)
    job = Job.find_by(id: job_id)
    if job.nil?
      Rails.logger.warn("[TestExecutionWorker] Job ##{job_id} not found — skipping.")
      return
    end

    Rails.logger.info("[TestExecutionWorker] Executing Job ##{job.id}")
    WorkerExecutor.execute(job)
  rescue StandardError => e
    # Safety net for failures that escape WorkerExecutor (e.g. DB down).
    Rails.logger.error("[TestExecutionWorker] Job ##{job_id} failed: #{e.message}")
    job = Job.find_by(id: job_id)
    job&.mark_failed!
    TestRunProgressUpdater.call(job.test_run) if job&.test_run
    raise
  end
end
