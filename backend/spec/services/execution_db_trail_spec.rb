require "rails_helper"

# Part 13 — DB wiring: execution must leave a complete, automatic trail behind
# without any manual bookkeeping. One run of WorkerExecutor should persist the
# job lifecycle (running -> uploading_artifacts -> completed), stream logs,
# store artifacts, attribute the job to the claimed worker, and keep the
# worker's busy state in sync.
RSpec.describe "Automatic execution DB trail", type: :service do
  let(:worker) { create(:worker_heartbeat, worker_name: "Worker-02") }
  let(:job) { create(:job) }
  let(:docker) { instance_double(DockerService) }
  let(:parser) { class_double(PlaywrightOutputParser) }
  let(:artifact_store) { double("artifact_store") }
  let(:container) { DockerService::Container.new(id: "abc123", name: "executehub-job-#{job.id}-abcd") }
  let(:job_dir) { ArtifactStore.job_dir(job) }
  let(:output_dir) { job_dir.join("artifacts") }

  let(:tmpdir) { Dir.mktmpdir }
  let(:video_path) { Pathname.new(tmpdir).join("video.webm") }

  let(:summary) do
    { passed: 2, failed: 0, duration_ms: 1234, tests: [], screenshots: [],
      videos: [video_path], traces: [] }
  end

  before do
    File.write(video_path, "webm")
    allow(artifact_store).to receive(:prepare).with(job).and_return(job_dir)
    allow(artifact_store).to receive(:job_dir).with(job).and_return(job_dir)
    allow(artifact_store).to receive(:relative).with(video_path).and_return("job_#{job.id}/artifacts/video.webm")
    allow(TestRunProgressUpdater).to receive(:call)
    allow(ArtifactUploadJob).to receive(:perform_async)
  end

  after do
    FileUtils.rm_rf(tmpdir)
    FileUtils.rm_rf(job_dir)
  end

  it "persists logs, artifacts, worker attribution and job lifecycle automatically" do
    allow(docker).to receive(:create).and_return(container)
    allow(docker).to receive(:start)
    allow(docker).to receive(:stream_logs).and_yield("  ✓  1 passed").and_yield("  ✓  2 passed")
    allow(docker).to receive(:exit_code).and_return(0)
    allow(docker).to receive(:copy)
    allow(parser).to receive(:parse)
      .with(output_dir.join("test-results.json"), output_dir).and_return(summary)
    allow(docker).to receive(:destroy)

    WorkerRegistry.claim!(worker.worker_name, job)
    WorkerExecutor.new(job, docker: docker, parser: parser,
                            artifact_store: artifact_store, worker: worker).execute

    job.reload
    expect(job.status).to eq("completed")
    expect(job.worker_id).to eq("Worker-02")
    expect(job.started_at).to be_present
    expect(job.finished_at).to be_present
    expect(job.container_id).to eq("abc123")
    expect(job.passed_tests).to eq(2)
    expect(job.failed_tests).to eq(0)
    expect(job.duration_ms).to be_present

    # ExecutionLogs streamed from Playwright + lifecycle entries.
    expect(job.execution_logs.count).to be >= 5
    expect(job.execution_logs.map(&:message)).to include("  ✓  1 passed")
    expect(job.execution_logs.pluck(:level).uniq - %w[info warn error]).to be_empty

    # Artifacts copied out of the container (video + exported execution log).
    expect(job.artifacts.size).to eq(2)
    expect(job.artifacts.map(&:artifact_type)).to include("video", "log")
    expect(job.artifacts.find_by(artifact_type: "video").size).to eq(4)

    # The claimed worker stays Busy on this job while it is executing.
    expect(worker.reload.status).to eq("busy")
    expect(worker.current_job_id).to eq(job.id)
  end
end
