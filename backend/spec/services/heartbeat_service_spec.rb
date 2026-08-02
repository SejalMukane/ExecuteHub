require "rails_helper"

RSpec.describe HeartbeatService, type: :service do
  describe ".beat" do
    it "upserts a heartbeat and refreshes last_seen_at" do
      worker = create(:worker_heartbeat, last_seen_at: 1.minute.ago)

      result = described_class.beat(worker.worker_name,
                                    status: "busy",
                                    current_job_id: nil,
                                    cpu_usage: 42.0,
                                    memory_usage: 33.3)

      expect(result).to eq(worker)
      worker.reload
      expect(worker.status).to eq("busy")
      expect(worker.cpu_usage).to eq(42.0)
      expect(worker.memory_usage).to eq(33.3)
      expect(worker.last_seen_at).to be_within(1.second).of(Time.current)
    end

    it "creates the worker record when it does not exist" do
      expect do
        described_class.beat("Worker-07", status: "idle", current_job_id: nil,
                                          cpu_usage: nil, memory_usage: nil)
      end.to change { WorkerHeartbeat.count }.by(1)

      expect(WorkerHeartbeat.find_by(worker_name: "Worker-07")).to be_present
    end

    it "records the current job on a busy worker" do
      job = create(:job)
      worker = create(:worker_heartbeat)

      described_class.beat(worker.worker_name, status: "busy", current_job_id: job.id,
                                                cpu_usage: nil, memory_usage: nil)

      expect(worker.reload.current_job_id).to eq(job.id)
    end
  end

  describe ".mark_stale_workers_offline!" do
    it "marks workers with an old heartbeat offline" do
      stale = create(:worker_heartbeat, worker_name: "Worker-01", last_seen_at: 30.seconds.ago)
      fresh = create(:worker_heartbeat, worker_name: "Worker-02", last_seen_at: Time.current)

      count = described_class.mark_stale_workers_offline!

      expect(count).to eq(1)
      expect(stale.reload.status).to eq("offline")
      expect(fresh.reload.status).to eq("idle")
    end

    it "does not touch workers that never existed" do
      expect(described_class.mark_stale_workers_offline!).to eq(0)
    end

    it "returns the number of workers that just went offline" do
      create(:worker_heartbeat, worker_name: "Worker-01", last_seen_at: 20.seconds.ago)
      create(:worker_heartbeat, worker_name: "Worker-02", last_seen_at: 20.seconds.ago)

      expect(described_class.mark_stale_workers_offline!).to eq(2)
    end
  end

  describe ".interval_seconds" do
    it "reads the configured heartbeat interval" do
      expect(described_class.interval_seconds).to eq(5)
    end
  end
end
