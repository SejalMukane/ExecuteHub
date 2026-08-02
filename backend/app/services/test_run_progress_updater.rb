# TestRunProgressUpdater recomputes a TestRun's counters and progress from the
# current state of its Jobs and moves the TestRun through its lifecycle
# (queued -> running). Terminal transitions (completed/failed) and the final
# execution summary are delegated to ResultAggregator, which only fires once
# every Job is in a terminal state.
#
#   progress_percentage = completed_jobs / total_jobs * 100
#
# Recomputing from the database (instead of incrementing) keeps the numbers
# consistent even when multiple Jobs finish concurrently.
class TestRunProgressUpdater
  TERMINAL_STATUSES = %w[completed failed].freeze

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

    # Live buckets: running = actively executing; queued = waiting (incl. retries).
    # The buckets partition total so dashboards can trust the sums.
    running_bucket = running + uploading
    queued_bucket = queued + retrying

    progress = total.zero? ? 0.0 : (completed.to_f / total * 100).round(1)

    @test_run.update!(
      total_jobs: total,
      completed_jobs: completed,
      failed_jobs: failed,
      queued_jobs: queued_bucket,
      running_jobs: running_bucket,
      progress_percentage: progress
    )

    transition_status(queued: queued, running: running, retrying: retrying, uploading: uploading)

    # Fan-in: once every job is terminal, aggregate the final summary.
    ResultAggregator.call(@test_run)

    Rails.logger.info(
      "[TestRunProgressUpdater] Progress Updated for TestRun ##{@test_run.id}: #{progress}% (#{completed}/#{total} jobs)"
    )
    @test_run
  end

  private

  # A run becomes "running" as soon as ANY job leaves the queue (started or
  # already finished but the run is not done yet). Terminal state is left to
  # ResultAggregator.
  def transition_status(queued:, running:, retrying:, uploading:)
    return unless @test_run.queued?
    return if @test_run.jobs.where.not(status: TERMINAL_STATUSES).none?

    active = running + retrying + uploading
    @test_run.update!(status: :running) if active.positive? || @test_run.completed_jobs.positive?
  end
end
