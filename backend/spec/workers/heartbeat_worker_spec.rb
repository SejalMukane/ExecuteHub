require "rails_helper"

RSpec.describe HeartbeatWorker, type: :worker do
  describe "#perform" do
    before do
      # Grant the lock and swallow its release so the worker never touches Redis.
      redis = double("redis")
      allow(redis).to receive(:set).and_return(true)
      allow(redis).to receive(:del).and_return(1)
      allow(Sidekiq).to receive(:redis).and_yield(redis)

      allow(HeartbeatWorker).to receive(:perform_in)
      allow(DashboardEventService).to receive(:broadcast_metrics)
    end

    it "ensures the worker pool exists" do
      described_class.new.perform
      expect(WorkerHeartbeat.count).to eq(5)
      expect(WorkerHeartbeat.pluck(:worker_name)).to match_array(
        %w[Worker-01 Worker-02 Worker-03 Worker-04 Worker-05]
      )
    end

    it "beats healthy workers and refreshes last_seen_at" do
      create(:worker_heartbeat, worker_name: "Worker-01", last_seen_at: Time.current)
      create(:worker_heartbeat, worker_name: "Worker-02", status: :busy, last_seen_at: Time.current)

      described_class.new.perform

      WorkerHeartbeat.find_each do |worker|
        expect(worker.reload.last_seen_at).to be_within(5.seconds).of(Time.current)
      end
    end

    it "does not beat stale workers and marks them offline" do
      stale = create(:worker_heartbeat, worker_name: "Worker-01", last_seen_at: 30.seconds.ago)

      described_class.new.perform

      expect(stale.reload.status).to eq("offline")
      expect(stale.last_seen_at).to be_within(1).of(30.seconds.ago)
    end

    it "self-reschedules the next pass" do
      described_class.new.perform
      expect(HeartbeatWorker).to have_received(:perform_in).with(HeartbeatService.interval_seconds)
    end

    it "skips the pass work when another instance holds the lock, but still schedules the next pass" do
      redis = double("redis")
      allow(redis).to receive(:set).and_return(false)
      allow(Sidekiq).to receive(:redis).and_yield(redis)

      expect { described_class.new.perform }.not_to change { WorkerHeartbeat.count }
      expect(HeartbeatWorker).to have_received(:perform_in).with(HeartbeatService.interval_seconds)
    end

    it "revives offline pool workers back to idle" do
      create(:worker_heartbeat, worker_name: "Worker-03", status: :offline,
                                last_seen_at: 1.minute.ago, execution_count: 4)

      described_class.new.perform

      revived = WorkerHeartbeat.find_by(worker_name: "Worker-03")
      expect(revived).to be_idle
      expect(revived.last_seen_at).to be_within(5.seconds).of(Time.current)
      expect(revived.execution_count).to eq(4)
    end

    it "recovers orphaned jobs before reviving the offline worker" do
      worker = create(:worker_heartbeat, worker_name: "Worker-02", status: :offline,
                                         last_seen_at: 1.minute.ago)
      job = create(:job, status: :running, worker_id: "Worker-02")
      worker.update!(current_job: job)
      allow(JobRetrier).to receive(:call)

      described_class.new.perform

      expect(JobRetrier).to have_received(:call).with(
        job, instance_of(LoadBalancer::WorkerCrashed), hash_including(type: :worker_crash)
      )
      expect(worker.reload).to be_idle
      expect(worker.current_job).to be_nil
    end
  end

  describe "startup bootstrap" do
    it "enqueues HeartbeatWorker whenever Sidekiq boots" do
      fake_config = Object.new
      def fake_config.on(kind)
        yield if kind == :startup
      end

      allow(Sidekiq).to receive(:configure_server).and_yield(fake_config)
      allow(HeartbeatWorker).to receive(:perform_async)

      load Rails.root.join("config/initializers/heartbeat_worker.rb")

      expect(HeartbeatWorker).to have_received(:perform_async)
    end
  end
end
