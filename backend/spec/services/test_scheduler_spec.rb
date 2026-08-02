require "rails_helper"

RSpec.describe TestScheduler, type: :service do
  let(:test_run) { create(:test_run, total_tests: 100) }
  let(:chunk_size) { 20 }

  before do
    Sidekiq::Queues.clear_all
  end

  after do
    Sidekiq::Queues.clear_all
  end

  describe ".call" do
    context "when total_tests divides evenly by chunk_size" do
      it "creates exactly ceil(total / chunk_size) jobs" do
        expect { described_class.call(test_run, chunk_size: chunk_size) }
          .to change { test_run.jobs.count }.from(0).to(5)
      end

      it "splits the tests into equal chunks" do
        described_class.call(test_run, chunk_size: chunk_size)
        expect(test_run.jobs.pluck(:test_count)).to eq([20, 20, 20, 20, 20])
      end
    end

    context "when total_tests does not divide evenly" do
      it "puts the remainder in the last chunk" do
        described_class.call(test_run, chunk_size: 30)
        expect(test_run.jobs.pluck(:test_count)).to eq([30, 30, 30, 10])
      end
    end

    it "numbers the chunks sequentially starting at 1" do
      described_class.call(test_run, chunk_size: chunk_size)
      expect(test_run.jobs.order(:chunk_number).pluck(:chunk_number)).to eq([1, 2, 3, 4, 5])
    end

    it "creates every job in the queued state" do
      described_class.call(test_run, chunk_size: chunk_size)
      expect(test_run.jobs.pluck(:status)).to all(eq("queued"))
    end

    it "enqueues one job per chunk onto the test_execution queue" do
      described_class.call(test_run, chunk_size: chunk_size)
      queued = Sidekiq::Queues["test_execution"]
      expect(queued.size).to eq(5)
      expect(queued.map { |entry| entry["class"] }).to all(eq("TestExecutionWorker"))
    end

    it "dispatches every job into the queue immediately (fan-out)" do
      described_class.call(test_run, chunk_size: chunk_size)
      expect(Sidekiq::Queues["test_execution"].size).to eq(test_run.jobs.count)
    end

    it "stays lightweight — it only creates and queues jobs, never executes them" do
      expect(WorkerExecutor).not_to receive(:execute)
      expect(TestExecutionWorker).to receive(:perform_async).exactly(5).times.and_call_original

      described_class.call(test_run, chunk_size: chunk_size)
    end

    it "enqueues the correct job ids" do
      described_class.call(test_run, chunk_size: chunk_size)
      job_ids = test_run.jobs.order(:chunk_number).pluck(:id)
      enqueued_args = Sidekiq::Queues["test_execution"].map { |entry| entry["args"].first }
      expect(enqueued_args).to match_array(job_ids)
    end

    it "updates the test run counters" do
      described_class.call(test_run, chunk_size: chunk_size)
      test_run.reload
      expect(test_run.total_jobs).to eq(5)
      expect(test_run.queued_jobs).to eq(5)
      expect(test_run.completed_jobs).to eq(0)
      expect(test_run.progress_percentage).to eq(0.0)
    end

    it "sets the run status to queued after scheduling" do
      described_class.call(test_run, chunk_size: chunk_size)
      expect(test_run.reload.status).to eq("queued")
    end

    it "stamps started_at" do
      expect { described_class.call(test_run, chunk_size: chunk_size) }
        .to change { test_run.reload.started_at }.from(nil)
    end

    it "uses the configured chunk_size when none is provided" do
      allow(Rails.configuration.executehub).to receive(:fetch).and_call_original
      allow(Rails.configuration.executehub).to receive(:fetch)
        .with("chunk_size", 20).and_return(25)

      described_class.call(test_run)
      expect(test_run.jobs.count).to eq(4)
      expect(test_run.jobs.pluck(:test_count)).to eq([25, 25, 25, 25])
    end

    it "uses the default chunk size (20) from config" do
      described_class.call(test_run)
      expect(test_run.jobs.count).to eq(5)
    end

    context "when total_tests is missing or zero" do
      it "does not create jobs" do
        broken = create(:test_run)
        broken.update_column(:total_tests, 0)
        expect { described_class.call(broken) }.not_to change { broken.jobs.count }
      end
    end
  end
end
