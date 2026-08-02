require "rails_helper"

RSpec.describe JobFailureClassifier, type: :service do
  describe ".call" do
    it "classifies Docker failures as retryable (docker_failure)" do
      result = described_class.call(DockerService::DockerError.new("docker create failed"))
      expect(result.reason).to eq("docker_failure")
      expect(result).to be_retryable
    end

    it "classifies network timeouts as retryable (network_timeout)" do
      result = described_class.call(Net::ReadTimeout.new)
      expect(result.reason).to eq("network_timeout")
      expect(result).to be_retryable
    end

    it "classifies connection refused as retryable (network_timeout)" do
      result = described_class.call(Errno::ECONNREFUSED.new)
      expect(result.reason).to eq("network_timeout")
      expect(result).to be_retryable
    end

    it "classifies an explicit worker crash as retryable (worker_crash)" do
      result = described_class.call(StandardError.new("worker died"), type: :worker_crash)
      expect(result.reason).to eq("worker_crash")
      expect(result).to be_retryable
    end

    it "does NOT retry test failures (assertion / browser test failures)" do
      result = described_class.call(StandardError.new("boom"), type: :test_failure)
      expect(result.reason).to eq("test_failure")
      expect(result).not_to be_retryable
    end

    it "does NOT retry execution timeouts" do
      result = described_class.call(Timeout::Error.new("execution exceeded 600s timeout"))
      expect(result.reason).to eq("execution_timeout")
      expect(result).not_to be_retryable
    end

    it "does NOT retry generic application errors" do
      result = described_class.call(ArgumentError.new("bad argument"))
      expect(result.reason).to eq("application_error")
      expect(result).not_to be_retryable
    end

    it "classifies a redis outage as retryable (network_timeout)" do
      error = Redis::CannotConnectError.new("Error connecting to Redis")
      expect(described_class.call(error)).to be_retryable
    end

    it "sniffs docker mentions in the error message" do
      result = described_class.call(StandardError.new("docker daemon is not running"))
      expect(result.reason).to eq("docker_failure")
      expect(result).to be_retryable
    end
  end
end
