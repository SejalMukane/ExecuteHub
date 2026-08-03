require "rails_helper"
require "sidekiq/api"

RSpec.describe QueueMetrics, type: :service do
  before do
    Sidekiq::Worker.clear_all
  end

  def stub_queue(jobs = [])
    queue = double("test_execution_queue", size: jobs.length)
    allow(queue).to receive(:map).and_return(jobs.map { |j| Time.at(j.enqueued_at) })
    allow(queue).to receive(:min_by).and_return(jobs.min_by { |j| j.enqueued_at })
    allow(Sidekiq::Queue).to receive(:new).with("test_execution").and_return(queue)
  end


  def stub_workset(running: 0)
    workset = instance_double(Sidekiq::WorkSet)
    allow(workset).to receive(:count).and_return(running)
    allow(Sidekiq::WorkSet).to receive(:new).and_return(workset)
  end

  it "returns empty queue metrics when nothing is queued" do
    stub_queue([])
    stub_workset(running: 0)

    metrics = described_class.call

    expect(metrics[:queue_size]).to eq(0)
    expect(metrics[:running_jobs]).to eq(0)
    expect(metrics[:average_wait_time]).to eq(0.0)
    expect(metrics[:longest_waiting_job]).to be_nil
    expect(metrics[:completed_today]).to eq(0)
    expect(metrics[:failed_today]).to eq(0)
    expect(metrics[:retry_count]).to eq(0)
  end

  it "counts completed and failed jobs today" do
    create(:job, status: :completed, finished_at: Time.current)
    create(:job, status: :completed, finished_at: 1.hour.ago)
    create(:job, status: :failed, finished_at: Time.current)
    create(:job, status: :failed, finished_at: 2.days.ago)

    stub_queue([])
    stub_workset(running: 0)
    metrics = described_class.call

    expect(metrics[:completed_today]).to eq(2)
    expect(metrics[:failed_today]).to eq(1)
  end

  it "counts retried jobs" do
    create(:job, retry_count: 1)
    create(:job, retry_count: 0)

    stub_queue([])
    stub_workset(running: 0)
    expect(described_class.call[:retry_count]).to eq(1)
  end

  it "reports the longest waiting job in the queue" do
    job = create(:job, status: :queued)
    enqueued = double("queued_job", args: [job.id], enqueued_at: 30.seconds.ago.to_f)
    stub_queue([enqueued])
    stub_workset(running: 1)

    metrics = described_class.call
    expect(metrics[:queue_size]).to eq(1)
    expect(metrics[:running_jobs]).to eq(1)
    expect(metrics[:longest_waiting_job]).to include(:job_id, :enqueued_at, :waiting_seconds)
    expect(metrics[:longest_waiting_job][:job_id]).to eq(job.id)
  end

  it "computes average wait time from the oldest queued job" do
    old = double("queued_job", args: [1], enqueued_at: 20.seconds.ago.to_f)
    stub_queue([old])
    stub_workset(running: 0)

    expect(described_class.call[:average_wait_time]).to be_within(0.5).of(20.0)
  end

end
