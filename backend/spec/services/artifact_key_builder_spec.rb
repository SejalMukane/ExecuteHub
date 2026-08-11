require "rails_helper"

RSpec.describe ArtifactKeyBuilder, type: :service do
  describe ".build" do
    it "builds the predictable executehub hierarchy with a unique filename" do
      project = create(:project)
      run = create(:test_run, project: project)
      job = create(:job, test_run: run)

      key = described_class.build(
        job: job,
        artifact_type: "screenshot",
        original_name: "login-failed.png"
      )

      parts = key.split("/")
      expect(parts).to eq([
        "executehub",
        "projects",
        "project_#{project.id}",
        "test_runs",
        "run_#{run.id}",
        "jobs",
        "job_#{job.id}",
        "screenshots",
        parts.last
      ])
      expect(parts.last).to end_with("login-failed.png")
      expect(parts.last).to match(/\A\d{8}_\d{6}_[0-9a-f]{8}_login-failed\.png\z/)
    end

    it "pluralizes every artifact type folder" do
      project = create(:project)
      run = create(:test_run, project: project)
      job = create(:job, test_run: run)

      {
        "screenshot" => "screenshots",
        "video" => "videos",
        "trace" => "traces",
        "log" => "logs",
        "report" => "reports"
      }.each do |type, folder|
        key = described_class.build(job: job, artifact_type: type, original_name: "file.bin")
        expect(key).to include("/#{folder}/")
      end
    end

    it "produces distinct keys for identical filenames (collision avoidance)" do
      job = create(:job)
      first = described_class.build(job: job, artifact_type: "screenshot", original_name: "same.png")
      second = described_class.build(job: job, artifact_type: "screenshot", original_name: "same.png")

      expect(first).not_to eq(second)
    end
  end
end
