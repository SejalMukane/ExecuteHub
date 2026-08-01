# TestScheduler fans a TestRun out into N Job chunks and pushes each Job onto
# the Sidekiq "test_execution" queue.
#
# Chunking:
#   number_of_jobs = ceil(total_tests / chunk_size)
#
# The chunk size is read from config/executehub.yml (default 20) and can be
# overridden per-call (mainly for tests).
class TestScheduler
  def self.call(test_run, chunk_size: nil)
    new(test_run, chunk_size: chunk_size).call
  end

  def initialize(test_run, chunk_size: nil)
    @test_run = test_run
    @chunk_size = chunk_size || Rails.configuration.executehub.fetch("chunk_size", 20).to_i
  end

  def call
    Rails.logger.info("[TestScheduler] Scheduler Started for TestRun ##{@test_run.id}")

    # Nothing to schedule when the run carries no tests. Guard before any DB
    # write so an invalid record never raises.
    return @test_run if @test_run.total_tests.to_i <= 0

    @test_run.update!(status: :scheduling, started_at: @test_run.started_at || Time.current)

    create_and_enqueue_jobs

    @test_run.update!(
      status: :queued,
      total_jobs: @test_run.jobs.count,
      queued_jobs: @test_run.jobs.queued.count,
      progress_percentage: 0.0
    )

    Rails.logger.info(
      "[TestScheduler] #{@test_run.total_jobs} Jobs Created and Queued for TestRun ##{@test_run.id}"
    )
    @test_run
  end

  private

  # Splits total_tests into chunks and creates + enqueues one Job per chunk.
  def create_and_enqueue_jobs
    remaining = @test_run.total_tests
    number_of_jobs = (remaining.to_f / @chunk_size).ceil

    number_of_jobs.times do |index|
      test_count = [@chunk_size, remaining].min
      remaining -= test_count

      job = @test_run.jobs.create!(
        chunk_number: index + 1,
        test_count: test_count,
        status: :queued
      )
      Rails.logger.info("[TestScheduler] Job ##{job.id} Created for TestRun ##{@test_run.id} (chunk #{job.chunk_number}, #{job.test_count} tests)")

      TestExecutionWorker.perform_async(job.id)
      Rails.logger.info("[TestScheduler] Job ##{job.id} Queued (enqueued to test_execution) for TestRun ##{@test_run.id}")
    end
  end
end
