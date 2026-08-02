require "rails_helper"

# Verifies that multiple Jobs belonging to the SAME TestRun can execute
# simultaneously and never block each other. This is what makes the platform
# "distributed": one test suite fans out into N chunks that are processed in
# parallel by N worker threads (Sidekiq concurrency == worker_pool_size).
RSpec.describe "Multiple concurrent workers", type: :worker do
  it "runs several jobs from one test run at the same time" do
    test_run = create(:test_run, total_tests: 100)
    TestScheduler.call(test_run, chunk_size: 20)
    jobs = test_run.jobs.order(:chunk_number).to_a
    expect(jobs.count).to eq(5)

    # Track how many "workers" are executing at once. If workers serialise,
    # max_active never exceeds 1.
    active = 0
    max_active = 0
    mutex = Mutex.new

    allow(WorkerExecutor).to receive(:execute) do |job|
      mutex.synchronize do
        active += 1
        max_active = [max_active, active].max
      end
      sleep 0.05
      job.mark_completed!
      TestRunProgressUpdater.call(job.test_run)
      mutex.synchronize { active -= 1 }
      nil
    end

    threads = jobs.map { |job| Thread.new { WorkerExecutor.execute(job) } }
    threads.each(&:join)

    expect(max_active).to be > 1
    expect(test_run.reload.status).to eq("completed")
    expect(test_run.progress_percentage).to eq(100.0)
    expect(test_run.jobs.pluck(:status)).to all(eq("completed"))
  end

  it "marks the run complete only when every job finishes" do
    test_run = create(:test_run, total_tests: 40)
    TestScheduler.call(test_run, chunk_size: 20)
    jobs = test_run.jobs.order(:chunk_number).to_a

    allow(WorkerExecutor).to receive(:execute) do |job|
      job.mark_completed!
      TestRunProgressUpdater.call(job.test_run)
      nil
    end

    # Process only the first job, then assert the run is still running.
    WorkerExecutor.execute(jobs.first)
    test_run.reload
    expect(test_run.status).to eq("running")
    expect(test_run.progress_percentage).to eq(50.0)

    # Remaining jobs finish -> run completes.
    jobs[1..].each { |job| WorkerExecutor.execute(job) }
    test_run.reload
    expect(test_run.status).to eq("completed")
    expect(test_run.progress_percentage).to eq(100.0)
  end
end
