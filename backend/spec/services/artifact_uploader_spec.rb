require "rails_helper"

RSpec.describe ArtifactUploader, type: :service do
  describe ".persist_artifacts" do
    let(:job) { create(:job, test_count: 2) }
    let(:tmpdir) { Dir.mktmpdir }
    let(:screenshot_path) { Pathname.new(tmpdir).join("failed.png") }
    let(:video_path) { Pathname.new(tmpdir).join("video.webm") }
    let(:log_path) { Pathname.new(tmpdir).join("execution.log") }

    before do
      File.write(screenshot_path, "png")
      File.write(video_path, "webm")
      File.write(log_path, "log data")
      allow(ArtifactUploadJob).to receive(:perform_async)
    end

    after { FileUtils.rm_rf(tmpdir) }

    it "creates pending artifact records for every collected file" do
      summary = {
        passed: 1, failed: 1, duration_ms: 1000, tests: [],
        screenshots: [screenshot_path], videos: [video_path], traces: [],
        logs: [log_path], reports: []
      }

      count = described_class.persist_artifacts(job, summary)

      expect(count).to eq(3)
      expect(job.artifacts.count).to eq(3)
      expect(job.artifacts.map(&:artifact_type)).to contain_exactly("screenshot", "video", "log")
      expect(job.artifacts.pluck(:status).uniq).to eq(["pending"])
      expect(job.artifacts.first.test_run_id).to eq(job.test_run_id)
    end

    it "generates s3 keys with the right hierarchy and metadata" do
      summary = { passed: 1, failed: 0, duration_ms: 1000, tests: [],
                  screenshots: [screenshot_path], videos: [], traces: [], logs: [], reports: [] }

      described_class.persist_artifacts(job, summary)

      artifact = job.artifacts.screenshots.first
      expect(artifact.s3_key).to include("project_#{job.test_run.project_id}")
      expect(artifact.s3_key).to include("run_#{job.test_run_id}")
      expect(artifact.s3_key).to include("job_#{job.id}")
      expect(artifact.s3_key).to include("/screenshots/")
      expect(artifact.file_name).to eq("failed.png")
      expect(artifact.size).to eq(3)
      expect(artifact.content_type).to eq("image/png")
    end

    it "enqueues one upload job per artifact" do
      summary = { passed: 1, failed: 0, duration_ms: 1000, tests: [],
                  screenshots: [screenshot_path], videos: [video_path], traces: [], logs: [], reports: [] }

      described_class.persist_artifacts(job, summary)

      expect(ArtifactUploadJob).to have_received(:perform_async).exactly(2).times
    end

    it "does not crash when Redis is unavailable — records stay pending" do
      summary = { passed: 1, failed: 0, duration_ms: 1000, tests: [],
                  screenshots: [screenshot_path], videos: [], traces: [], logs: [], reports: [] }
      allow(ArtifactUploadJob).to receive(:perform_async).and_raise(RedisClient::CannotConnectError, "down")

      expect { described_class.persist_artifacts(job, summary) }.not_to raise_error
      expect(job.artifacts.first.status).to eq("pending")
    end

    it "returns zero when nothing was collected" do
      summary = { passed: 0, failed: 0, duration_ms: 0, tests: [],
                  screenshots: [], videos: [], traces: [], logs: [], reports: [] }

      expect(described_class.persist_artifacts(job, summary)).to eq(0)
      expect(job.artifacts.count).to eq(0)
    end
  end

  describe ".checksum" do
    it "computes a SHA-256 hex digest" do
      file = File.join(Dir.mktmpdir, "x.bin")
      File.write(file, "hello")

      expect(described_class.checksum(file)).to eq(Digest::SHA256.file(file).hexdigest)
      FileUtils.rm_rf(File.dirname(file))
    end
  end
end
