# TestScheduler is the fan-out step of a TestRun: it splits total_tests into N
# Job chunks and immediately dispatches EVERY Job onto the Sidekiq
# "test_execution" queue. This is the ONLY thing the scheduler does.
#
#   TestRun -> split into chunks -> create Jobs -> queue every Job
#
# The scheduler stays lightweight on purpose:
#   - NO execution logic (workers own that)
#   - NO result aggregation (ResultAggregator owns that)
#   - NO worker assignment (WorkerRegistry + load balancing own that)
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
    log("Scheduler started for TestRun ##{@test_run.id}")

    # Nothing to schedule when the run carries no tests. Guard before any DB
    # write so an invalid record never raises.
    return @test_run if @test_run.total_tests.to_i <= 0

    @test_run.update!(status: :scheduling, started_at: @test_run.started_at || Time.current)

    jobs = create_jobs
    dispatch_jobs(jobs)

    @test_run.update!(
      status: :queued,
      total_jobs: jobs.size,
      queued_jobs: jobs.size,
      completed_jobs: 0,
      failed_jobs: 0,
      progress_percentage: 0.0
    )

    DashboardEventService.test_run_started(@test_run)
    DashboardEventService.queue_updated

    log("#{jobs.size} Jobs created and queued for TestRun ##{@test_run.id}")
    @test_run
  end

  private

  # Splits total_tests into equal-ish chunks (remainder goes in the last one)
  # and persists one queued Job per chunk. Persistence only — nothing runs yet.
  def create_jobs
    remaining = @test_run.total_tests
    number_of_jobs = (remaining.to_f / @chunk_size).ceil

    Array.new(number_of_jobs) do |index|
      test_count = [@chunk_size, remaining].min
      remaining -= test_count

      job = @test_run.jobs.create!(
        chunk_number: index + 1,
        test_count: test_count,
        status: :queued
      )
      DashboardEventService.job_created(job)
      log("Job ##{job.id} created (chunk #{job.chunk_number}, #{job.test_count} tests)")
      job
    end
  end

  # The fan-out: push every Job into Redis immediately. Workers pull them
  # concurrently and never block each other. No job is ever left behind.
  def dispatch_jobs(jobs)
    jobs.each do |job|
      TestExecutionWorker.perform_async(job.id)
      log("Job ##{job.id} dispatched to test_execution")
    end
  end

  def log(message)
    Rails.logger.info("[TestScheduler] #{message}")
  end
end
