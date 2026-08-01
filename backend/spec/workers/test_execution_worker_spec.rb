require "rails_helper"

RSpec.describe TestExecutionWorker, type: :worker do
  describe "#perform" do
    it "delegates the job to WorkerExecutor" do
      job = create(:job)

      expect(WorkerExecutor).to receive(:execute).with(job)

      described_class.new.perform(job.id)
    end

    it "is a no-op when the job no longer exists" do
      expect { described_class.new.perform(999_999) }.not_to raise_error
    end

    it "marks the job failed and re-raises when execution raises" do
      test_run = create(:test_run)
      job = create(:job, test_run: test_run)

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
