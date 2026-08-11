require "rails_helper"

RSpec.describe DashboardEventService, type: :service do
  before do
    @broadcasts = []
    allow(ActionCable.server).to receive(:broadcast) do |stream, payload|
      @broadcasts << [stream, payload]
    end
  end

  describe ".job_started" do
    it "broadcasts to jobs, job_<id>, test_run_<id> and dashboard" do
      job = create(:job, status: :running, started_at: Time.current)

      described_class.job_started(job)

      streams = @broadcasts.map(&:first)
      expect(streams).to include("jobs", "job_#{job.id}", "test_run_#{job.test_run_id}", "dashboard")
      expect(streams).to include("queue") # queue refresh

      payload = @broadcasts.find { |s, _| s == "jobs" }.last
      expect(payload[:type]).to eq(:job_started)
      expect(payload[:job][:id]).to eq(job.id)
      expect(payload[:job][:container_id]).to eq(job.container_id)
    end
  end

  describe ".job_completed" do
    it "broadcasts the completed status" do
      job = create(:job, status: :completed, started_at: Time.current, finished_at: Time.current)

      described_class.job_completed(job)

      payload = @broadcasts.find { |s, _| s == "jobs" }&.last
      expect(payload[:type]).to eq(:job_completed)
      expect(payload[:job][:status]).to eq("completed")
    end
  end

  describe ".job_failed" do
    it "broadcasts the failed status" do
      job = create(:job, status: :failed, started_at: Time.current, finished_at: Time.current)

      described_class.job_failed(job)

      payload = @broadcasts.find { |s, _| s == "jobs" }&.last
      expect(payload[:type]).to eq(:job_failed)
      expect(payload[:job][:status]).to eq("failed")
    end
  end

  describe ".test_run_started" do
    it "broadcasts the start event and progress snapshot" do
      test_run = create(:test_run, status: :queued, progress_percentage: 0.0)

      described_class.test_run_started(test_run)

      expect(@broadcasts.map(&:first)).to include("test_run_#{test_run.id}", "dashboard", "queue")
      start_payload = @broadcasts.find { |_, p| p[:type] == :test_run_started }&.last
      expect(start_payload[:test_run][:project_name]).to eq(test_run.project.name)
    end
  end

  describe ".test_run_progress_updated" do
    it "broadcasts the progress snapshot to the run and dashboard" do
      test_run = create(:test_run, progress_percentage: 42.0)

      described_class.test_run_progress_updated(test_run)

      progress = @broadcasts.find { |_, p| p[:type] == :test_run_progress_updated }&.last
      expect(progress[:test_run][:progress_percentage]).to eq(42.0)
    end
  end

  describe ".test_run_completed" do
    it "broadcasts completion and execution_finished" do
      test_run = create(:test_run, status: :completed, progress_percentage: 100.0)

      described_class.test_run_completed(test_run)

      expect(@broadcasts.map(&:first)).to include("test_run_#{test_run.id}", "dashboard", "queue")
      finished = @broadcasts.find { |_, p| p[:type] == :execution_finished }&.last
      expect(finished[:test_run_id]).to eq(test_run.id)
    end
  end

  describe ".worker_heartbeat / .worker_online / .worker_offline" do
    it "broadcasts worker events to the workers stream and dashboard" do
      worker = create(:worker_heartbeat, status: :busy, cpu_usage: 60.0)

      described_class.worker_heartbeat(worker)
      described_class.worker_online(worker)
      described_class.worker_offline(worker)

      types = @broadcasts.filter_map { |s, p| p[:type] if s == "workers" }
      expect(types).to eq(%i[worker_heartbeat worker_online worker_offline])

      heartbeat = @broadcasts.find { |_, p| p[:type] == :worker_heartbeat }&.last
      expect(heartbeat[:worker][:worker_name]).to eq(worker.worker_name)
      expect(heartbeat[:worker][:cpu_usage]).to eq(60.0)
      expect(heartbeat[:worker][:browser]).to eq("Chrome")
    end
  end

  describe ".worker_registered" do
    it "broadcasts a registration event" do
      worker = create(:worker_heartbeat, status: :idle)

      described_class.worker_registered(worker)

      payload = @broadcasts.find { |_, p| p[:type] == :worker_registered }&.last
      expect(payload[:worker][:worker_name]).to eq(worker.worker_name)
    end
  end

  describe ".queue_updated" do
    it "broadcasts queue metrics to the queue and dashboard streams" do
      described_class.queue_updated(queue_size: 3, running_jobs: 1)

      streams = @broadcasts.map(&:first)
      expect(streams).to include("queue", "dashboard")
      payload = @broadcasts.find { |s, _| s == "queue" }.last
      expect(payload[:type]).to eq(:queue_updated)
      expect(payload[:queue][:queue_size]).to eq(3)
    end
  end

  describe ".artifacts_uploaded" do
    it "broadcasts artifact upload to the run and dashboard" do
      job = create(:job)

      described_class.artifacts_uploaded(job, 4)

      streams = @broadcasts.map(&:first)
      expect(streams).to include("test_run_#{job.test_run_id}", "dashboard")
      payload = @broadcasts.find { |s, _| s == "dashboard" }.last
      expect(payload[:type]).to eq(:artifacts_uploaded)
      expect(payload[:artifacts][:artifact_count]).to eq(4)
    end
  end

  describe ".artifact_upload_started / .artifact_uploaded / .artifact_failed" do
    it "broadcasts artifact lifecycle events to the run and dashboard" do
      artifact = create(:artifact, artifact_type: :screenshot, status: :uploading)

      described_class.artifact_upload_started(artifact)
      described_class.artifact_uploaded(artifact)
      described_class.artifact_failed(artifact, "no space left")

      types = @broadcasts.filter_map { |s, p| p[:type] if s == "dashboard" }
      expect(types).to eq(%i[artifact_upload_started artifact_uploaded artifact_failed])

      uploaded = @broadcasts.find { |_, p| p[:type] == :artifact_uploaded }&.last
      expect(uploaded[:artifact][:id]).to eq(artifact.id)
      expect(uploaded[:artifact][:artifact_type]).to eq("screenshot")

      failed = @broadcasts.find { |_, p| p[:type] == :artifact_failed }&.last
      expect(failed[:error]).to eq("no space left")
    end
  end

  describe ".report_generated" do
    it "broadcasts the generated report to the run and dashboard" do
      run = create(:test_run, status: :completed)
      report = create(:test_report, test_run: run, success_rate: 90.0)

      described_class.report_generated(run)

      payload = @broadcasts.find { |_, p| p[:type] == :report_generated }&.last
      expect(payload[:test_run_id]).to eq(run.id)
      expect(payload[:report][:id]).to eq(report.id)
      expect(payload[:report][:success_rate]).to eq(90.0)
    end
  end

  describe ".test_result_completed" do
    it "broadcasts a single test outcome" do
      job = create(:job)
      result = create(:test_result, job: job, test_run: job.test_run, status: :failed)

      described_class.test_result_completed(result)

      payload = @broadcasts.find { |_, p| p[:type] == :test_result_completed }&.last
      expect(payload[:test_result][:id]).to eq(result.id)
      expect(payload[:test_result][:status]).to eq("failed")
      expect(payload[:test_result][:job_id]).to eq(job.id)
    end
  end

  describe ".test_run_analytics_updated" do
    it "broadcasts refreshed analytics for the run and dashboard" do
      run = create(:test_run, status: :completed)

      described_class.test_run_analytics_updated(run)

      payload = @broadcasts.find { |_, p| p[:type] == :test_run_analytics_updated }&.last
      expect(payload[:test_run_id]).to eq(run.id)
      expect(@broadcasts.map(&:first)).to include("test_run_#{run.id}", "dashboard")
    end
  end

  it "is failure-tolerant when ActionCable is unavailable" do
    allow(ActionCable.server).to receive(:broadcast).and_raise("cable down")

    expect { described_class.job_started(create(:job)) }.not_to raise_error
    expect { described_class.test_run_progress_updated(create(:test_run)) }.not_to raise_error
    expect { described_class.worker_heartbeat(create(:worker_heartbeat)) }.not_to raise_error
  end
end
