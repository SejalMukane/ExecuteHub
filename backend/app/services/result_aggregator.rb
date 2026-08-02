# ResultAggregator is the fan-in step of a distributed TestRun. It is invoked
# after every Job changes state and only does real work once EVERY Job
# belonging to the TestRun has reached a terminal state (completed or failed).
#
#   wait until every Job finishes
#     -> aggregate results
#     -> update TestRun
#     -> generate final summary
#
# The final summary includes:
#   - passed tests          (sum of every completed job's passed_tests)
#   - failed tests          (sum of every job's failed_tests)
#   - total duration        (sum of all job durations)
#   - total screenshots     (artifacts across all jobs)
#   - total videos          (artifacts across all jobs)
#   - overall status        completed when no job failed, else failed
#
# The service is idempotent — it is safe to call on every job completion and
# simply no-ops until the run is fully terminal.
class ResultAggregator
  TERMINAL_STATUSES = %w[completed failed].freeze

  def self.call(test_run)
    new(test_run).call
  end

  def initialize(test_run)
    @test_run = test_run
  end

  def call
    return unless all_jobs_terminal?

    aggregate!
    @test_run
  end

  private

  def all_jobs_terminal?
    @test_run.jobs.count.positive? &&
      @test_run.jobs.where.not(status: TERMINAL_STATUSES).none?
  end

  # Aggregates every job's summary into the TestRun and writes the final
  # status + finished_at. with_lock guards against two workers finishing the
  # last two jobs at the same moment and both computing the summary.
  def aggregate!
    @test_run.with_lock do
      counts = {
        passed_tests: @test_run.jobs.sum(:passed_tests),
        failed_tests: @test_run.jobs.sum(:failed_tests),
        total_duration_ms: @test_run.jobs.sum(:duration_ms),
        total_screenshots: @test_run.jobs.joins(:artifacts)
                                  .where(artifacts: { artifact_type: "screenshot" }).count,
        total_videos: @test_run.jobs.joins(:artifacts)
                               .where(artifacts: { artifact_type: "video" }).count,
        status: @test_run.jobs.failed.exists? ? :failed : :completed,
        finished_at: Time.current
      }

      @test_run.update!(counts)
      log("Summary generated: #{counts[:passed_tests]} passed, #{counts[:failed_tests]} failed, " \
          "#{counts[:total_screenshots]} screenshots, #{counts[:total_videos]} videos")
    end
  end

  def log(message)
    Rails.logger.info("[ResultAggregator] TestRun ##{@test_run.id}: #{message}")
  end
end
