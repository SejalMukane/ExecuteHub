require "rails_helper"

RSpec.describe TestExecutionWorker, type: :worker do
  describe "#perform" do
    it "processes a queued job to completion and updates progress" do
      test_run = create(:test_run)
      job = create(:job, test_run: test_run, status: :queued)

      allow_any_instance_of(described_class).to receive(:sleep)

      described_class.new.perform(job.id)

      job.reload
      test_run.reload

      expect(job.status).to eq("completed")
      expect(job.finished_at).to be_present
      expect(test_run.completed_jobs).to eq(1)
      expect(test_run.progress_percentage).to eq(100.0)
      expect(test_run.status).to eq("completed")
    end

    it "sets the worker_id when starting" do
      job = create(:job)
      allow_any_instance_of(described_class).to receive(:sleep)

      described_class.new.perform(job.id)

      expect(job.reload.worker_id).to be_present
      expect(job.started_at).to be_present
    end

    it "is a no-op when the job no longer exists" do
      expect do
        described_class.new.perform(999_999)
      end.not_to raise_error
    end

    it "marks the job failed when execution raises" do
      test_run = create(:test_run)
      job = create(:job, test_run: test_run, status: :running, started_at: Time.current)

      allow_any_instance_of(described_class).to receive(:sleep).and_raise("boom")

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
