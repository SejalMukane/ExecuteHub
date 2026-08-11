require "rails_helper"

RSpec.describe ArtifactCleanupJob, type: :worker do
  let(:job_instance) { described_class.new }

  before do
    allow(described_class).to receive(:perform_in)
    allow(job_instance).to receive(:acquire_lock).and_return(true)
    allow(job_instance).to receive(:release_lock)
  end

  describe "#perform" do
    it "schedules the next pass" do
      job_instance.perform
      expect(described_class).to have_received(:perform_in)
    end

    it "deletes expired uploaded artifacts from storage and the database" do
      old_job = create(:job)
      expired = create(:artifact, job: old_job, status: :uploaded, created_at: 31.days.ago)
      fresh = create(:artifact, job: old_job, status: :uploaded, created_at: 1.day.ago)

      expect(StorageService.adapter).to receive(:delete).with(expired.s3_key)

      deleted = job_instance.send(:cleanup_expired_artifacts)

      expect(deleted).to eq(1)
      expect(Artifact.exists?(expired.id)).to be(false)
      expect(Artifact.exists?(fresh.id)).to be(true)
    end

    it "does not touch artifacts still pending upload" do
      old_job = create(:job)
      pending = create(:artifact, job: old_job, status: :pending, created_at: 31.days.ago)

      expect(StorageService.adapter).not_to receive(:delete)

      job_instance.perform

      expect(Artifact.exists?(pending.id)).to be(true)
    end

    it "survives storage failures and keeps other artifacts working" do
      old_job = create(:job)
      failing = create(:artifact, job: old_job, status: :uploaded, created_at: 31.days.ago)
      passing = create(:artifact, job: old_job, status: :uploaded, created_at: 31.days.ago)

      expect(StorageService.adapter).to receive(:delete).with(failing.s3_key).and_raise(S3StorageService::S3Error, "down")
      expect(StorageService.adapter).to receive(:delete).with(passing.s3_key)

      expect(job_instance.perform).to be_truthy
      expect(Artifact.exists?(failing.id)).to be(true)
      expect(Artifact.exists?(passing.id)).to be(false)
    end
  end

  describe "#retention_days" do
    it "reads ARTIFACT_RETENTION_DAYS from the environment" do
      ENV["ARTIFACT_RETENTION_DAYS"] = "7"
      expect(job_instance.send(:retention_days)).to eq(7)
    ensure
      ENV.delete("ARTIFACT_RETENTION_DAYS")
    end

    it "falls back to the configured default" do
      expect(job_instance.send(:retention_days)).to eq(30)
    end
  end
end
