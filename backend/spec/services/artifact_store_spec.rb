require "rails_helper"

RSpec.describe ArtifactStore, type: :service do
  describe ".job_dir" do
    it "formats the per-job folder with zero padding" do
      job = build(:job, id: 7)
      expect(described_class.job_dir(job).to_s).to end_with("job_07")
    end
  end

  describe ".relative / .resolve" do
    it "round-trips between absolute and storage-relative paths" do
      job = build(:job, id: 3)
      absolute = described_class.job_dir(job).join("artifacts", "video.webm")

      relative = described_class.relative(absolute)
      expect(relative).to eq("job_03/artifacts/video.webm")
      expect(described_class.resolve(relative)).to eq(absolute)
    end
  end

  describe ".prepare" do
    it "creates the per-job directory" do
      job = create(:job)
      dir = described_class.prepare(job)

      expect(Dir.exist?(dir)).to be(true)
    ensure
      FileUtils.rm_rf(dir)
    end
  end
end
