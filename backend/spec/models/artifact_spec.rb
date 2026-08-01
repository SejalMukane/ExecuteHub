require "rails_helper"

RSpec.describe Artifact, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:job) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:path) }
    it { is_expected.to validate_inclusion_of(:artifact_type).in_array(%w[screenshot video trace]) }
  end

  describe "scopes" do
    it "filters artifacts by type" do
      job = create(:job)
      screenshot = create(:artifact, job: job, artifact_type: :screenshot)
      video = create(:artifact, job: job, artifact_type: :video)
      trace = create(:artifact, job: job, artifact_type: :trace)

      expect(job.artifacts.screenshots).to eq([screenshot])
      expect(job.artifacts.videos).to eq([video])
      expect(job.artifacts.traces).to eq([trace])
    end
  end

  describe "artifact creation" do
    it "records metadata for an execution artifact" do
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
      expect(artifact.path).to end_with("video.webm")
      expect(artifact.size).to eq(4096)
    end
  end
end
