# TestRunProgressUpdater recomputes a TestRun's counters and progress from the
# current state of its Jobs and moves the TestRun through its lifecycle
# (queued -> running -> completed/failed).
#
#   progress_percentage = completed_jobs / total_jobs * 100
#
# Recomputing from the database (instead of incrementing) keeps the numbers
# consistent even when multiple Jobs finish concurrently.
class TestRunProgressUpdater
  def self.call(test_run)
    new(test_run).call
  end

  def initialize(test_run)
    @test_run = test_run
  end

  def call
    counts = @test_run.jobs.group(:status).count
    total = counts.values.sum
    completed = counts.fetch("completed", 0)
    failed = counts.fetch("failed", 0)
    queued = counts.fetch("queued", 0)
    running = counts.fetch("running", 0)
    retrying = counts.fetch("retrying", 0)
    uploading = counts.fetch("uploading_artifacts", 0)

    progress = total.zero? ? 0.0 : (completed.to_f / total * 100).round(1)

    @test_run.update!(
      total_jobs: total,
      completed_jobs: completed,
      failed_jobs: failed,
      queued_jobs: queued,
      progress_percentage: progress
    )

    transition_status(queued: queued, running: running, retrying: retrying,
                      uploading: uploading, failed: failed)

    Rails.logger.info(
      "[TestRunProgressUpdater] Progress Updated for TestRun ##{@test_run.id}: #{progress}% (#{completed}/#{total} jobs)"
    )
    @test_run
  end

  private

  # Runs the TestRun to completion only when every Job is in a terminal state.
  # Jobs that are still running/uploading/retrying keep the run active.
  #
  # The run moves from queued -> running as soon as ANY job leaves the queue
  # (started or already finished but the run is not done yet), so a run that is
  # being processed by multiple concurrent workers is always reported as
  # "running" rather than "queued".
  def transition_status(queued:, running:, retrying:, uploading:, failed:)
    active = running + retrying + uploading

    if queued.zero? && active.zero? && @test_run.jobs.count.positive?
      @test_run.update!(status: failed.positive? ? :failed : :completed, finished_at: Time.current)
    elsif @test_run.queued? && (active.positive? || @test_run.completed_jobs.positive?)
      @test_run.update!(status: :running)
    end
  end
end
