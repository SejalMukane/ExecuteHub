require "timeout"
require "net/http"
require "socket"

# JobFailureClassifier decides whether a Job failure is worth retrying and
# labels it with a machine-readable reason.
#
# Retryable (infrastructure problems — retrying is safe):
#   docker_failure   - the Docker daemon / container failed
#   worker_crash     - the worker process died or stopped responding mid-job
#   network_timeout  - connection problems talking to external services
#
# NOT retryable (re-running won't help):
#   test_failure     - Playwright assertion / browser test failed
#   execution_timeout- job exceeded its execution budget
#   application_error- an application bug raised an unexpected exception
#
# The classification is used by JobRetrier to decide between retrying and
# permanently failing the Job.
class JobFailureClassifier
  RETRYABLE_REASONS = %w[docker_failure worker_crash network_timeout].freeze

  # Immutable result of a classification.
  class Classification
    attr_reader :reason

    def initialize(reason)
      @reason = reason
    end

    def retryable?
      RETRYABLE_REASONS.include?(@reason)
    end
  end

  def self.call(error, type: nil)
    new(error, type: type).call
  end

  # Convenience predicate for specs / callers that only care about retryability.
  def self.retryable?(error, type: nil)
    call(error, type: type).retryable?
  end

  def initialize(error, type: nil)
    @error = error
    @type = type
  end

  def call
    return classify(@type) if @type && REASONS_BY_TYPE.key?(@type)

    if docker_error?
      classify(:docker_failure)
    elsif network_error?
      classify(:network_timeout)
    elsif timeout_error?
      classify(:execution_timeout)
    else
      classify(:application_error)
    end
  end

  private

  REASONS_BY_TYPE = {
    docker: :docker_failure,
    worker_crash: :worker_crash,
    network: :network_timeout,
    timeout: :execution_timeout,
    test_failure: :test_failure
  }.freeze

  def classify(reason)
    Classification.new(reason.to_s)
  end

  def docker_error?
    @error.is_a?(DockerService::DockerError) || message.match?(/docker/i)
  end

  def network_error?
    NETWORK_ERROR_CLASSES.any? { |klass| @error.is_a?(klass) } || message.match?(/connection refused|no route to host|timed out|read timeout/i)
  end

  def timeout_error?
    @error.is_a?(Timeout::Error) || message.match?(/exceeded.*timeout/i)
  end

  def message
    @error.respond_to?(:message) ? @error.message.to_s : @error.to_s
  end

  NETWORK_ERROR_CLASSES = [
    Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::EPIPE,
    Errno::EHOSTUNREACH, Errno::ENETUNREACH,
    SocketError, Net::ReadTimeout, Net::OpenTimeout,
    Redis::CannotConnectError
  ].freeze
end
