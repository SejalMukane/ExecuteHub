require "rails_helper"

RSpec.describe WorkerHeartbeat, type: :model do
  describe "validations" do
    it "requires a worker_name" do
      expect(build(:worker_heartbeat, worker_name: nil)).not_to be_valid
    end

    it "requires a unique worker_name" do
      create(:worker_heartbeat, worker_name: "Worker-01")
      expect(build(:worker_heartbeat, worker_name: "Worker-01")).not_to be_valid
    end

    it "enforces the Worker-XX name format" do
      expect(build(:worker_heartbeat, worker_name: "worker-1")).not_to be_valid
      expect(build(:worker_heartbeat, worker_name: "Worker-01")).to be_valid
    end
  end

  describe "status" do
    it "defaults to idle" do
      expect(create(:worker_heartbeat).status).to eq("idle")
    end

    it "marks busy with a current job" do
      job = create(:job)
      worker = create(:worker_heartbeat)
      worker.mark_busy!(job)

      expect(worker.reload.status).to eq("busy")
      expect(worker.current_job).to eq(job)
    end

    it "marks idle clears the current job" do
      worker = create(:worker_heartbeat, status: :busy, current_job: create(:job))
      worker.mark_idle!

      expect(worker.reload.status).to eq("idle")
      expect(worker.current_job).to be_nil
    end

    it "marks offline" do
      worker = create(:worker_heartbeat)
      worker.mark_offline!

      expect(worker.reload.status).to eq("offline")
      expect(worker).to be_offline
    end
  end

  describe "scopes" do
    it "filters active / available / busy / offline" do
      create(:worker_heartbeat, worker_name: "Worker-01", status: :idle)
      create(:worker_heartbeat, worker_name: "Worker-02", status: :busy)
      create(:worker_heartbeat, worker_name: "Worker-03", status: :offline)

      expect(WorkerHeartbeat.active.pluck(:worker_name)).to match_array(%w[Worker-01 Worker-02])
      expect(WorkerHeartbeat.available.pluck(:worker_name)).to eq(%w[Worker-01])
      expect(WorkerHeartbeat.busy.pluck(:worker_name)).to eq(%w[Worker-02])
      expect(WorkerHeartbeat.offline.pluck(:worker_name)).to eq(%w[Worker-03])
    end
  end

  describe "health" do
    it "is healthy when seen recently" do
      worker = create(:worker_heartbeat, last_seen_at: Time.current)
      expect(worker).to be_healthy
    end

    it "is unhealthy when the heartbeat is stale" do
      worker = create(:worker_heartbeat, last_seen_at: 30.seconds.ago)
      expect(worker).not_to be_healthy
    end

    it "is unhealthy when offline" do
      worker = create(:worker_heartbeat, status: :offline, last_seen_at: Time.current)
      expect(worker).not_to be_healthy
    end
  end
end
