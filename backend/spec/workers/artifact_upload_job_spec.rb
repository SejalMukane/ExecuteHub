require "rails_helper"

RSpec.describe ArtifactUploadJob, type: :worker do
  describe "#perform" do
    it "uploads the artifact in the background" do
      artifact = create(:artifact, status: :pending)

      expect(ArtifactUploader).to receive(:upload).with(artifact)

      described_class.new.perform(artifact.id)
    end

    it "skips silently when the artifact no longer exists" do
      expect(ArtifactUploader).not_to receive(:upload)

      described_class.new.perform(99_999)
    end
  end
end
