require "rails_helper"

RSpec.describe WorkerRegistry, type: :service do
  let(:job) { create(:job) }

  describe ".register!" do
    it "registers a new worker as idle and healthy" do
      worker = described_class.register!("Worker-01")

      expect(worker.status).to eq("idle")
      expect(worker.last_seen_at).to be_within(1.second).of(Time.current)
      expect(worker.execution_count).to eq(0)
      expect(described_class.counts[:total]).to eq(1)
    end

    it "is idempotent for an existing worker" do
      described_class.register!("Worker-01")

      expect { described_class.register!("Worker-01") }.not_to change { WorkerHeartbeat.count }
    end

    it "revives an offline worker back to idle" do
      worker = create(:worker_heartbeat, status: :offline, last_seen_at: 1.minute.ago)

      described_class.register!(worker.worker_name)

      expect(worker.reload.status).to eq("idle")
      expect(worker.last_seen_at).to be_within(1.second).of(Time.current)
      expect(worker.current_job_id).to be_nil
    end
  end

  describe ".claim_available!" do
    it "claims an idle worker for the job and marks it busy" do
      worker = create(:worker_heartbeat, worker_name: "Worker-01", status: :idle)

      claimed = described_class.claim_available!(job)

      expect(claimed).to eq(worker)
      expect(worker.reload.status).to eq("busy")
      expect(worker.current_job_id).to eq(job.id)
      expect(worker.last_seen_at).to be_within(1.second).of(Time.current)
    end

    it "returns nil when every worker is busy" do
      create(:worker_heartbeat, worker_name: "Worker-01", status: :busy)

      expect(described_class.claim_available!(job)).to be_nil
    end

    it "never claims an offline worker" do
      create(:worker_heartbeat, worker_name: "Worker-01", status: :offline)
      create(:worker_heartbeat, worker_name: "Worker-02", status: :busy)

      expect(described_class.claim_available!(job)).to be_nil
    end

    it "prefers idle workers over busy ones" do
      busy = create(:worker_heartbeat, worker_name: "Worker-01", status: :busy)
      idle = create(:worker_heartbeat, worker_name: "Worker-02", status: :idle)

      claimed = described_class.claim_available!(job)

      expect(claimed).to eq(idle)
      expect(busy.reload.status).to eq("busy")
    end
  end

  describe ".claim!" do
    it "claims a named idle worker" do
      worker = create(:worker_heartbeat, worker_name: "Worker-03", status: :idle)

      claimed = described_class.claim!("Worker-03", job)

      expect(claimed).to eq(worker)
      expect(worker.reload.status).to eq("busy")
      expect(worker.current_job_id).to eq(job.id)
    end

    it "raises when the named worker is busy" do
      create(:worker_heartbeat, worker_name: "Worker-03", status: :busy)

      expect { described_class.claim!("Worker-03", job) }
        .to raise_error(WorkerRegistry::WorkerUnavailableError, /busy/)
    end

    it "raises when the named worker is offline" do
      create(:worker_heartbeat, worker_name: "Worker-03", status: :offline)

      expect { described_class.claim!("Worker-03", job) }
        .to raise_error(WorkerRegistry::WorkerUnavailableError, /offline/)
    end
  end

  describe ".release!" do
    it "releases a busy worker back to idle and bumps its execution count" do
      worker = create(:worker_heartbeat, worker_name: "Worker-01", status: :busy,
                                         current_job: job, execution_count: 2)

      released = described_class.release!(worker)

      expect(released).to eq(worker)
      expect(worker.reload.status).to eq("idle")
      expect(worker.current_job_id).to be_nil
      expect(worker.execution_count).to eq(3)
      expect(worker.last_seen_at).to be_within(1.second).of(Time.current)
    end

    it "accepts a worker name string" do
      worker = create(:worker_heartbeat, worker_name: "Worker-01", status: :busy)

      described_class.release!("Worker-01")

      expect(worker.reload.status).to eq("idle")
      expect(worker.execution_count).to eq(1)
    end

    it "returns nil for an unknown worker" do
      expect(described_class.release!("Worker-99")).to be_nil
    end
  end

  describe ".available" do
    it "only lists idle workers, sorted by name" do
      busy = create(:worker_heartbeat, worker_name: "Worker-01", status: :busy)
      offline = create(:worker_heartbeat, worker_name: "Worker-02", status: :offline)
      idle_b = create(:worker_heartbeat, worker_name: "Worker-03", status: :idle)
      idle_a = create(:worker_heartbeat, worker_name: "Worker-04", status: :idle)

      expect(described_class.available).to eq([idle_b, idle_a])
      expect(described_class.available).not_to include(busy, offline)
    end
  end

  describe ".offline?" do
    it "is true only for offline workers" do
      create(:worker_heartbeat, worker_name: "Worker-01", status: :offline)
      create(:worker_heartbeat, worker_name: "Worker-02", status: :idle)

      expect(described_class.offline?("Worker-01")).to be(true)
      expect(described_class.offline?("Worker-02")).to be(false)
      expect(described_class.offline?("Worker-99")).to be(false)
    end
  end

  describe ".counts" do
    it "summarizes the pool by status" do
      create(:worker_heartbeat, worker_name: "Worker-01", status: :idle)
      create(:worker_heartbeat, worker_name: "Worker-02", status: :busy)
      create(:worker_heartbeat, worker_name: "Worker-03", status: :busy)
      create(:worker_heartbeat, worker_name: "Worker-04", status: :offline)

      expect(described_class.counts).to eq(total: 4, idle: 1, busy: 2, offline: 1)
    end

    it "returns zeros for an empty pool" do
      expect(described_class.counts).to eq(total: 0, idle: 0, busy: 0, offline: 0)
    end
  end
end
