require "rails_helper"

RSpec.describe Artifact, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:job) }
    it { is_expected.to belong_to(:test_run).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:path) }
    it { is_expected.to validate_presence_of(:test_run_id) }
    it { is_expected.to validate_inclusion_of(:artifact_type).in_array(%w[screenshot video trace log report]) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[pending uploading uploaded failed]) }
  end

  describe "scopes" do
    it "filters artifacts by type" do
      job = create(:job)
      screenshot = create(:artifact, job: job, artifact_type: :screenshot)
      video = create(:artifact, job: job, artifact_type: :video)
      trace = create(:artifact, job: job, artifact_type: :trace)
      log = create(:artifact, job: job, artifact_type: :log)
      report = create(:artifact, job: job, artifact_type: :report)

      expect(job.artifacts.screenshots).to eq([screenshot])
      expect(job.artifacts.videos).to eq([video])
      expect(job.artifacts.traces).to eq([trace])
      expect(job.artifacts.logs).to eq([log])
      expect(job.artifacts.reports).to eq([report])
    end

    it "filters by upload status" do
      job = create(:job)
      uploaded = create(:artifact, job: job, status: :uploaded)
      failed = create(:artifact, job: job, status: :failed)

      expect(job.artifacts.uploaded).to eq([uploaded])
      expect(job.artifacts.failed).to eq([failed])
      expect(job.artifacts.pending).to include(failed)
    end
  end

  describe "artifact creation" do
    it "records metadata for an execution artifact and derives test_run from its job" do
      job = create(:job)
      artifact = create(
        :artifact,
        job: job,
        artifact_type: :video,
        path: "job_01/artifacts/video.webm",
        size: 4096
      )

      expect(job.artifacts.count).to eq(1)
      expect(artifact.artifact_type).to eq("video")
      expect(artifact.test_run_id).to eq(job.test_run_id)
      expect(artifact.file_name).to eq("video.webm")
      expect(artifact.file_size).to eq(4096)
    end

    it "rejects unknown artifact types" do
      artifact = build(:artifact, artifact_type: "binary")
      expect(artifact).not_to be_valid
    end
  end

  describe "#upload!" do
    it "uploads to remote storage, stores a checksum and broadcasts success" do
      job = create(:job)
      artifact = create(:artifact, job: job, status: :pending)
      local_path = ArtifactStore.resolve(artifact.path)
      FileUtils.mkdir_p(local_path.dirname)
      File.write(local_path, "artifact bytes")

      expect(StorageService.adapter).to receive(:upload)
        .with(local_path, artifact.s3_key, content_type: anything)
        .and_return(true)
      expect(DashboardEventService).to receive(:artifact_uploaded).with(artifact)

      expect(artifact.upload!).to be(true)
      expect(artifact.reload.status).to eq("uploaded")
      expect(artifact.checksum).to eq(Digest::SHA256.file(local_path).hexdigest)
    ensure
      FileUtils.rm_rf(ArtifactStore.job_dir(job)) if defined?(job) && job
    end

    it "marks the artifact failed and broadcasts the error when storage raises" do
      job = create(:job)
      artifact = create(:artifact, job: job, status: :pending)
      local_path = ArtifactStore.resolve(artifact.path)
      FileUtils.mkdir_p(local_path.dirname)
      File.write(local_path, "artifact bytes")

      expect(StorageService.adapter).to receive(:upload).and_raise(S3StorageService::S3Error, "bucket missing")
      expect(DashboardEventService).to receive(:artifact_failed).with(artifact, /bucket missing/)

      expect(artifact.upload!).to be(false)
      expect(artifact.reload.status).to eq("failed")
    ensure
      FileUtils.rm_rf(ArtifactStore.job_dir(job)) if defined?(job) && job
    end
  end
end
