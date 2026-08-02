require "rails_helper"

RSpec.describe JobRetrier, type: :service do
  let(:job) { create(:job) }

  describe ".call" do
    context "with a retryable failure and retries remaining" do
      it "records retry history and marks the job retrying" do
        error = DockerService::DockerError.new("container failed")

        expect { described_class.call(job, error) }
          .to change { job.reload.status }.from("queued").to("retrying")
          .and change { job.retry_count }.from(0).to(1)

        retry_record = job.job_retries.last
        expect(retry_record.attempt).to eq(1)
        expect(retry_record.reason).to eq("docker_failure")
        expect(retry_record.error_message).to eq("container failed")
        expect(retry_record.retried_at).to be_present
      end

      it "re-enqueues the job for another worker to pick up" do
        allow(TestExecutionWorker).to receive(:perform_in)

        described_class.call(job, Net::ReadTimeout.new)

        expect(TestExecutionWorker).to have_received(:perform_in).with(5, job.id)
      end

      it "does not mark the job failed" do
        described_class.call(job, Errno::ECONNREFUSED.new)

        expect(job.reload.status).to eq("retrying")
        expect(job.finished_at).to be_nil
      end

      it "returns :retried" do
        expect(described_class.call(job, DockerService::DockerError.new("x"))).to eq(:retried)
      end

      it "records one retry entry per attempt" do
        2.times { described_class.call(job, DockerService::DockerError.new("x")) }

        expect(job.reload.retry_count).to eq(2)
        expect(job.job_retries.pluck(:attempt)).to eq([1, 2])
      end
    end

    context "when the maximum retries are exhausted" do
      it "permanently fails the job" do
        job.update!(retry_count: 3)

        expect { described_class.call(job, DockerService::DockerError.new("x")) }
          .to change { job.reload.status }.from("queued").to("failed")

        expect(job.error_type).to eq("docker_failure")
        expect(job.error_message).to eq("x")
        expect(job.finished_at).to be_present
      end

      it "does not enqueue another attempt" do
        job.update!(retry_count: 3)
        allow(TestExecutionWorker).to receive(:perform_in)

        described_class.call(job, DockerService::DockerError.new("x"))

        expect(TestExecutionWorker).not_to have_received(:perform_in)
      end

      it "returns :failed" do
        job.update!(retry_count: 3)
        expect(described_class.call(job, DockerService::DockerError.new("x"))).to eq(:failed)
      end
    end

    context "with a non-retryable failure" do
      it "fails the job immediately without recording a retry" do
        error = StandardError.new("assertion failed")
        result = described_class.call(job, error, type: :test_failure)

        expect(result).to eq(:failed)
        job.reload
        expect(job.status).to eq("failed")
        expect(job.error_type).to eq("test_failure")
        expect(job.error_message).to eq("assertion failed")
        expect(job.job_retries.count).to eq(0)
      end

      it "does not enqueue anything" do
        allow(TestExecutionWorker).to receive(:perform_in)

        described_class.call(job, ArgumentError.new("bug"), type: nil)

        expect(TestExecutionWorker).not_to have_received(:perform_in)
      end
    end

    it "respects the configured max retries" do
      allow(Rails.configuration.executehub).to receive(:fetch).and_call_original
      allow(Rails.configuration.executehub).to receive(:fetch)
        .with("max_job_retries", 3).and_return(1)
      job.update!(retry_count: 1)

      expect(described_class.call(job, DockerService::DockerError.new("x"))).to eq(:failed)
    end
  end
end
