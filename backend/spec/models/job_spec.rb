require "rails_helper"

RSpec.describe Job, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:test_run) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:chunk_number) }
    it { is_expected.to validate_presence_of(:test_count) }

    it "rejects a non-positive chunk_number" do
      job = build(:job, chunk_number: 0)
      expect(job).not_to be_valid
    end

    it "rejects a non-positive test_count" do
      job = build(:job, test_count: 0)
      expect(job).not_to be_valid
    end
  end

  describe "status enum" do
    it "defaults to queued" do
      expect(described_class.new.status).to eq("queued")
    end

    it "exposes the documented statuses" do
      expect(described_class.statuses.keys).to match_array(
        %w[queued running completed failed retrying]
      )
    end
  end

  describe "#mark_running!" do
    it "sets status to running, stamps started_at and assigns a worker" do
      job = create(:job, status: :queued)
      expect { job.mark_running! }
        .to change { job.reload.status }.from("queued").to("running")
        .and change { job.started_at }.from(nil)
      expect(job.worker_id).to be_present
    end
  end

  describe "#mark_completed!" do
    it "sets status to completed and stamps finished_at" do
      job = create(:job, status: :running, started_at: Time.current)
      expect { job.mark_completed! }
        .to change { job.reload.status }.from("running").to("completed")
        .and change { job.finished_at }.from(nil)
    end
  end

  describe "#mark_failed!" do
    it "sets status to failed and stamps finished_at" do
      job = create(:job, status: :running, started_at: Time.current)
      expect { job.mark_failed! }
        .to change { job.reload.status }.from("running").to("failed")
        .and change { job.finished_at }.from(nil)
    end
  end

  describe "#mark_retrying!" do
    it "sets status to retrying and increments retry_count" do
      job = create(:job, status: :failed, retry_count: 1)
      expect { job.mark_retrying! }
        .to change { job.reload.status }.from("failed").to("retrying")
        .and change { job.retry_count }.from(1).to(2)
    end
  end
end
