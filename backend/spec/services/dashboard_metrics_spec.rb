require "rails_helper"

RSpec.describe DashboardMetrics, type: :service do
  it "returns zeros when the platform is empty" do
    metrics = described_class.call

    expect(metrics[:total_projects]).to eq(0)
    expect(metrics[:running_test_runs]).to eq(0)
    expect(metrics[:queued_jobs]).to eq(0)
    expect(metrics[:running_jobs]).to eq(0)
    expect(metrics[:completed_jobs]).to eq(0)
    expect(metrics[:failed_jobs]).to eq(0)
    expect(metrics[:active_workers]).to eq(0)
    expect(metrics[:idle_workers]).to eq(0)
    expect(metrics[:offline_workers]).to eq(0)
    expect(metrics[:worker_utilization]).to eq(0.0)
    expect(metrics[:success_rate]).to eq(100.0)
    expect(metrics[:average_execution_time]).to be_nil
    expect(metrics[:average_queue_wait_time]).to eq(0.0)
    expect(metrics[:updated_at]).to be_present
  end

  it "counts live jobs and workers" do
    project = create(:project)
    create(:test_run, project: project, status: "running")
    create(:test_run, project: project, status: "completed")
    create(:job, status: :queued)
    create(:job, status: :running)
    create(:job, status: :completed)
    create(:job, status: :failed)
    create(:worker_heartbeat, status: :idle)
    create(:worker_heartbeat, status: :busy)
    create(:worker_heartbeat, status: :offline)

    metrics = described_class.call

    expect(metrics[:total_projects]).to eq(Project.count)
    expect(metrics[:running_test_runs]).to eq(1)
    expect(metrics[:queued_jobs]).to eq(1)
    expect(metrics[:running_jobs]).to eq(1)
    expect(metrics[:completed_jobs]).to eq(1)
    expect(metrics[:failed_jobs]).to eq(1)
    expect(metrics[:active_workers]).to eq(2)
    expect(metrics[:idle_workers]).to eq(1)
    expect(metrics[:offline_workers]).to eq(1)
  end

  it "computes success rate from completed and failed jobs" do
    create(:job, status: :completed)
    create(:job, status: :completed)
    create(:job, status: :failed)

    expect(described_class.call[:success_rate]).to eq(66.7)
  end

  it "computes average execution time from job durations" do
    create(:job, status: :completed, duration_ms: 2000)
    create(:job, status: :completed, duration_ms: 4000)

    expect(described_class.call[:average_execution_time]).to eq(3.0)
  end

  it "computes average queue wait time from created_at to started_at" do
    job = create(:job, status: :running, started_at: 10.seconds.ago)
    job.update_columns(created_at: 40.seconds.ago)

    expect(described_class.call[:average_queue_wait_time]).to be_within(0.5).of(30.0)
  end

  it "computes worker utilization from busy workers" do
    create(:worker_heartbeat, status: :idle)
    create(:worker_heartbeat, status: :busy)
    create(:worker_heartbeat, status: :busy)

    expect(described_class.call[:worker_utilization]).to eq(66.7)
  end
end
