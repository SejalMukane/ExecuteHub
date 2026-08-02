require "rails_helper"

RSpec.describe RealtimeBroadcaster, type: :service do
  before do
    @broadcasts = []
    allow(ActionCable.server).to receive(:broadcast) do |stream, payload|
      @broadcasts << [stream, payload]
    end
  end

  describe ".job_started" do
    it "broadcasts job lifecycle to jobs, job_<id> and test_run_<id> streams" do
      job = create(:job, status: :running, started_at: Time.current)

      described_class.job_started(job)

      streams = @broadcasts.map(&:first)
      expect(streams).to include("jobs", "job_#{job.id}", "test_run_#{job.test_run_id}")

      payload = @broadcasts.find { |s, _| s == "jobs" }.last
      expect(payload[:type]).to eq("job_started")
      expect(payload[:job][:id]).to eq(job.id)
      expect(payload[:job][:status]).to eq("running")
      expect(payload[:job][:chunk_number]).to eq(job.chunk_number)
    end
  end

  describe ".job_finished" do
    it "broadcasts with the terminal status" do
      job = create(:job, status: :completed, started_at: Time.current, finished_at: Time.current)

      described_class.job_finished(job)

      payload = @broadcasts.find { |s, _| s == "jobs" }.last
      expect(payload[:type]).to eq("job_finished")
      expect(payload[:job][:status]).to eq("completed")
      expect(payload[:job][:finished_at]).to be_present
    end
  end

  describe ".run_progress" do
    it "broadcasts the progress snapshot to the run's stream" do
      test_run = create(:test_run, progress_percentage: 42.0)

      described_class.run_progress(test_run)

      expect(@broadcasts.map(&:first)).to eq(["test_run_#{test_run.id}"])
      payload = @broadcasts.first.last
      expect(payload[:type]).to eq("run_progress")
      expect(payload[:test_run][:id]).to eq(test_run.id)
      expect(payload[:test_run][:progress_percentage]).to eq(42.0)
    end
  end

  describe ".worker_heartbeat" do
    it "broadcasts a worker's heartbeat to the workers stream" do
      worker = create(:worker_heartbeat, status: :busy, cpu_usage: 60.0)

      described_class.worker_heartbeat(worker)

      expect(@broadcasts.map(&:first)).to eq(["workers"])
      payload = @broadcasts.first.last
      expect(payload[:type]).to eq("worker_heartbeat")
      expect(payload[:worker][:worker_name]).to eq(worker.worker_name)
      expect(payload[:worker][:status]).to eq("busy")
      expect(payload[:worker][:cpu_usage]).to eq(60.0)
    end
  end

  describe ".worker_offline / .worker_online" do
    it "broadcasts the transition and worker identity" do
      worker = create(:worker_heartbeat, status: :offline)

      described_class.worker_offline(worker)
      described_class.worker_online(worker)

      expect(@broadcasts.map { |_, p| p[:type] }).to eq(%w[worker_offline worker_online])
      expect(@broadcasts.first.last[:worker][:worker_name]).to eq(worker.worker_name)
    end
  end

  it "is failure-tolerant when ActionCable is unavailable" do
    allow(ActionCable.server).to receive(:broadcast).and_raise("cable down")

    expect { described_class.job_started(create(:job)) }.not_to raise_error
    expect { described_class.run_progress(create(:test_run)) }.not_to raise_error
    expect { described_class.worker_heartbeat(create(:worker_heartbeat)) }.not_to raise_error
  end
end
