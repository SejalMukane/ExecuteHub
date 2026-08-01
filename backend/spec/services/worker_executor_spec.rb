require "rails_helper"

RSpec.describe WorkerExecutor, type: :service do
  subject(:executor) { described_class.new(job, docker: docker, parser: parser, artifact_store: artifact_store) }

  let(:job) { create(:job, test_count: 2) }
  let(:docker) { instance_double(DockerService) }
  let(:parser) { class_double(PlaywrightOutputParser) }
  let(:artifact_store) { double("artifact_store") }
  let(:container) { DockerService::Container.new(id: "abc123", name: "executehub-job-#{job.id}-abcd") }
  let(:job_dir) { ArtifactStore.job_dir(job) }
  let(:output_dir) { job_dir.join("artifacts") }

  let(:tmpdir) { Dir.mktmpdir }
  let(:video_path) { Pathname.new(tmpdir).join("video.webm") }
  let(:trace_path) { Pathname.new(tmpdir).join("trace.zip") }

  let(:empty_summary) do
    { passed: 2, failed: 0, duration_ms: 12346, tests: [], screenshots: [], videos: [], traces: [] }
  end
  let(:summary_with_artifacts) do
    { passed: 2, failed: 0, duration_ms: 12346, tests: [], screenshots: [],
      videos: [video_path], traces: [trace_path] }
  end

  before do
    File.write(video_path, "webm")
    File.write(trace_path, "zip")
    allow(artifact_store).to receive(:prepare).with(job).and_return(job_dir)
    allow(artifact_store).to receive(:relative).with(video_path).and_return("job_#{job.id}/artifacts/video.webm")
    allow(artifact_store).to receive(:relative).with(trace_path).and_return("job_#{job.id}/artifacts/trace.zip")
    allow(TestRunProgressUpdater).to receive(:call)
  end

  after do
    FileUtils.rm_rf(tmpdir)
    FileUtils.rm_rf(job_dir)
  end

  describe "#execute" do
    context "when the pipeline succeeds" do
      it "runs the full lifecycle, persists the summary and marks the job completed" do
        expect(job).to receive(:mark_running!).and_call_original
        expect(docker).to receive(:create).with(
          name: /\Aexecutehub-job-#{job.id}-/,
          image: "executehub-playwright:latest",
          command: ["npx", "playwright", "test"],
          workdir: "/app"
        ).and_return(container)
        expect(docker).to receive(:start).with(container)
        expect(docker).to receive(:stream_logs).with(container).and_yield("  ✓  1 passed")
        expect(docker).to receive(:exit_code).with(container).and_return(0)
        expect(job).to receive(:mark_uploading_artifacts!).and_call_original
        expect(docker).to receive(:copy)
          .with(container, source: "/app/artifacts", destination: job_dir)
        expect(parser).to receive(:parse)
          .with(output_dir.join("test-results.json"), output_dir).and_return(summary_with_artifacts)
        expect(job).to receive(:mark_completed!).and_call_original
        expect(TestRunProgressUpdater).to receive(:call).with(job.test_run)
        expect(docker).to receive(:destroy).with(container)

        executor.execute

        job.reload
        expect(job.status).to eq("completed")
        expect(job.container_id).to eq("abc123")
        expect(job.passed_tests).to eq(2)
        expect(job.failed_tests).to eq(0)
        expect(job.duration_ms).to be_present
        expect(job.finished_at).to be_present
        expect(job.artifacts.size).to eq(2)
        expect(job.artifacts.map(&:artifact_type)).to contain_exactly("video", "trace")
      end
    end

    context "when Playwright reports failing tests" do
      it "marks the job failed with the failing count" do
        summary = empty_summary.merge(failed: 1, passed: 1)

        allow(docker).to receive(:create).and_return(container)
        allow(docker).to receive(:start)
        allow(docker).to receive(:stream_logs)
        allow(docker).to receive(:exit_code).and_return(0)
        allow(docker).to receive(:copy)
        allow(parser).to receive(:parse).and_return(summary)
        expect(docker).to receive(:destroy).with(container)

        executor.execute

        job.reload
        expect(job.status).to eq("failed")
        expect(job.error_message).to eq("Playwright reported 1 failed test(s)")
        expect(job.failed_tests).to eq(1)
      end
    end

    context "when the container cannot be created" do
      it "marks the job failed and stores the Docker error" do
        allow(docker).to receive(:create)
          .and_raise(DockerService::DockerError, "No such image: executehub-playwright:latest")

        executor.execute

        job.reload
        expect(job.status).to eq("failed")
        expect(job.error_message).to include("No such image")
        expect(job.finished_at).to be_present
      end
    end

    context "when artifact upload fails" do
      it "wraps docker cp failures into an ExecutionError message" do
        allow(docker).to receive(:create).and_return(container)
        allow(docker).to receive(:start)
        allow(docker).to receive(:stream_logs)
        allow(docker).to receive(:exit_code).and_return(0)
        allow(docker).to receive(:copy).and_raise(DockerService::DockerError, "cp failed")
        expect(docker).to receive(:destroy).with(container)

        executor.execute

        job.reload
        expect(job.status).to eq("failed")
        expect(job.error_message).to include("Artifact upload failed: cp failed")
      end

      it "fails when the Playwright report file is missing" do
        allow(docker).to receive(:create).and_return(container)
        allow(docker).to receive(:start)
        allow(docker).to receive(:stream_logs)
        allow(docker).to receive(:exit_code).and_return(0)
        allow(docker).to receive(:copy)
        allow(parser).to receive(:parse).and_raise(Errno::ENOENT)
        expect(docker).to receive(:destroy).with(container)

        executor.execute

        job.reload
        expect(job.status).to eq("failed")
        expect(job.error_message).to include("Artifact upload failed")
      end
    end

    it "always destroys the container, even on failure" do
      allow(docker).to receive(:create).and_return(container)
      allow(docker).to receive(:start)
      allow(docker).to receive(:stream_logs)
      allow(docker).to receive(:exit_code).and_raise("docker inspect exploded")
      expect(docker).to receive(:destroy).with(container)

      executor.execute

      job.reload
      expect(job.status).to eq("failed")
    end

    it "skips blank and ANSI-only streamed lines when storing logs" do
      allow(docker).to receive(:create).and_return(container)
      allow(docker).to receive(:start)
      allow(docker).to receive(:stream_logs)
        .and_yield("").and_yield("\e[0m").and_yield("  ✓  1 passed")
      allow(docker).to receive(:exit_code).and_return(0)
      allow(docker).to receive(:copy)
      allow(parser).to receive(:parse).and_return(empty_summary)
      expect(docker).to receive(:destroy).with(container)

      executor.execute

      messages = job.execution_logs.map(&:message)
      expect(messages).to include("  ✓  1 passed")
      expect(messages.all?(&:present?)).to be(true)
    end

    it "destroys the container even when Docker errors midway" do
      allow(docker).to receive(:create).and_return(container)
      allow(docker).to receive(:start).and_raise(DockerService::DockerError, "start failed")
      expect(docker).to receive(:destroy).with(container)

      executor.execute

      job.reload
      expect(job.status).to eq("failed")
      expect(job.error_message).to include("start failed")
    end
  end
end
