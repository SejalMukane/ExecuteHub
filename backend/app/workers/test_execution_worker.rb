# TestExecutionWorker simulates the execution of a single test chunk.
#
# Week 3 scope: scheduling + queueing only. No Playwright/browser execution is
# performed yet — the worker logs each lifecycle step and then reports progress
# back to the parent TestRun.
class TestExecutionWorker
  include Sidekiq::Worker

  sidekiq_options queue: "test_execution", retry: 3, backtrace: true

  def perform(job_id)
    job = Job.find_by(id: job_id)
    if job.nil?
      Rails.logger.warn("[TestExecutionWorker] Job ##{job_id} not found — skipping.")
      return
    end

    job.mark_running!
    Rails.logger.info("[TestExecutionWorker] Running Job ##{job.id}")

    # Simulated work (no real browser execution yet).
    sleep(simulated_delay)
    Rails.logger.info("[TestExecutionWorker] Sleeping... (Job ##{job.id})")

    job.mark_completed!
    Rails.logger.info("[TestExecutionWorker] Completed Job ##{job.id}")

    TestRunProgressUpdater.call(job.test_run)
  rescue StandardError => e
    Rails.logger.error("[TestExecutionWorker] Job ##{job_id} failed: #{e.message}")
    job = Job.find_by(id: job_id)
    job&.mark_failed!
    TestRunProgressUpdater.call(job.test_run) if job&.test_run
    raise
  end

  private

  def simulated_delay
    Rails.configuration.executehub.fetch("worker_simulate_delay", 1).to_f
  end
end
