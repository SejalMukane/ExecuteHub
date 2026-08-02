require "rails_helper"

RSpec.describe LoadBalancer, type: :service do
  describe ".claim!" do
    it "claims the next available worker for the job" do
      worker = create(:worker_heartbeat, worker_name: "Worker-01", status: :idle)
      job = create(:job)

      claimed = described_class.claim!(job)

      expect(claimed).to eq(worker)
      expect(worker.reload.status).to eq("busy")
      expect(worker.current_job_id).to eq(job.id)
    end

    it "returns nil when every worker is busy" do
      create(:worker_heartbeat, worker_name: "Worker-01", status: :busy)
      create(:worker_heartbeat, worker_name: "Worker-02", status: :offline)

      expect(described_class.claim!(create(:job))).to be_nil
    end
  end

  describe ".requeue!" do
    it "re-enqueues the job with a backoff and keeps it queued" do
      job = create(:job)
      allow(TestExecutionWorker).to receive(:perform_in)

      described_class.requeue!(job, backoff: 2)

      expect(job.reload.status).to eq("queued")
      expect(TestExecutionWorker).to have_received(:perform_in).with(2, job.id)
    end
  end

  describe ".recover_orphans!" do
    it "recovers jobs whose worker went offline mid-run" do
      test_run = create(:test_run)
      job = create(:job, test_run: test_run, status: :running, started_at: Time.current,
                         container_id: "abc")
      worker = create(:worker_heartbeat, worker_name: "Worker-01", status: :offline,
                                         current_job: job, last_seen_at: 1.minute.ago)
      allow(TestExecutionWorker).to receive(:perform_in)

      expect { described_class.recover_orphans! }.to change { job.job_retries.count }.by(1)

      expect(worker.reload.current_job_id).to be_nil
      job.reload
      expect(job.status).to eq("retrying")
      expect(job.job_retries.last.reason).to eq("worker_crash")
      expect(job.job_retries.last.error_message).to include("Worker-01 went offline")
      expect(job.container_id).to be_nil
      expect(job.started_at).to be_nil
      expect(TestExecutionWorker).to have_received(:perform_in).with(5, job.id)
    end

    it "recovers jobs stuck uploading artifacts" do
      job = create(:job, status: :uploading_artifacts)
      create(:worker_heartbeat, worker_name: "Worker-01", status: :offline, current_job: job)

      expect { described_class.recover_orphans! }.to change { job.job_retries.count }.by(1)
    end

    it "leaves non-in-flight jobs alone" do
      completed = create(:job, status: :completed)
      create(:worker_heartbeat, worker_name: "Worker-01", status: :offline, current_job: completed)

      expect { described_class.recover_orphans! }.not_to change { completed.job_retries.count }
      expect(completed.reload.status).to eq("completed")
    end

    it "permanently fails an orphan whose worker kept dying (retry limit reached)" do
      job = create(:job, status: :running, retry_count: 3)
      create(:worker_heartbeat, worker_name: "Worker-01", status: :offline, current_job: job)

      expect { described_class.recover_orphans! }.not_to change { job.job_retries.count }

      job.reload
      expect(job.status).to eq("failed")
      expect(job.error_type).to eq("worker_crash")
    end

    it "returns the number of recovered jobs" do
      create(:job, status: :running).tap { |j| create(:worker_heartbeat, worker_name: "Worker-01", status: :offline, current_job: j) }
      create(:job, status: :running).tap { |j| create(:worker_heartbeat, worker_name: "Worker-02", status: :offline, current_job: j) }

      expect(described_class.recover_orphans!).to eq(2)
    end

    it "returns zero when there is nothing to recover" do
      create(:job, status: :running)
      create(:worker_heartbeat, worker_name: "Worker-01", status: :busy)
      create(:worker_heartbeat, worker_name: "Worker-02", status: :offline)

      expect(described_class.recover_orphans!).to eq(0)
    end
  end

  describe ".dispatch_queued!" do
    it "claims and dispatches queued jobs to available workers" do
      job = create(:job, status: :queued)
      create(:worker_heartbeat, worker_name: "Worker-01", status: :idle)
      allow(TestExecutionWorker).to receive(:perform_async)

      count = described_class.dispatch_queued!

      expect(count).to eq(1)
      expect(WorkerHeartbeat.find_by(worker_name: "Worker-01").status).to eq("busy")
      expect(TestExecutionWorker).to have_received(:perform_async).with(job.id)
    end

    it "does not dispatch a job when no worker is available" do
      create(:job, status: :queued)
      create(:worker_heartbeat, worker_name: "Worker-01", status: :busy)
      allow(TestExecutionWorker).to receive(:perform_async)

      expect(described_class.dispatch_queued!).to eq(0)
      expect(TestExecutionWorker).not_to have_received(:perform_async)
    end

    it "respects a dispatch limit" do
      create_list(:job, 3, status: :queued)
      create_list(:worker_heartbeat, 5, status: :idle)

      expect(described_class.dispatch_queued!(limit: 2)).to eq(2)
    end
  end
end
