require "rails_helper"

RSpec.describe TestExecutionWorker, type: :worker do
  describe "#perform" do
    it "claims an available worker, executes on it, and releases it" do
      job = create(:job)
      worker = create(:worker_heartbeat, worker_name: "Worker-01", status: :idle)

      expect(WorkerExecutor).to receive(:execute).with(job, worker: worker)

      described_class.new.perform(job.id)

      worker.reload
      expect(worker.status).to eq("idle")
      expect(worker.current_job_id).to be_nil
      expect(worker.execution_count).to eq(1)
    end

    it "requeues the job when every worker is busy" do
      job = create(:job)
      create(:worker_heartbeat, worker_name: "Worker-01", status: :busy)
      allow(TestExecutionWorker).to receive(:perform_in)

      expect(WorkerExecutor).not_to receive(:execute)

      described_class.new.perform(job.id)

      expect(job.reload.status).to eq("queued")
      expect(TestExecutionWorker).to have_received(:perform_in).with(5, job.id)
    end

    it "is a no-op when the job no longer exists" do
      expect { described_class.new.perform(999_999) }.not_to raise_error
    end

    it "marks the job failed and re-raises when execution raises" do
      test_run = create(:test_run)
      job = create(:job, test_run: test_run)
      create(:worker_heartbeat, worker_name: "Worker-01", status: :idle)

      allow(WorkerExecutor).to receive(:execute).and_raise("boom")

      expect { described_class.new.perform(job.id) }.to raise_error("boom")

      job.reload
      expect(job.status).to eq("failed")
      expect(job.finished_at).to be_present
    end

    it "queues itself on the test_execution queue" do
      expect(described_class.get_sidekiq_options["queue"]).to eq("test_execution")
    end
  end
end
