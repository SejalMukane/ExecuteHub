# JobRetrier decides what happens when a Job fails and performs the bookkeeping:
#
#   retryable failure + retries remaining
#     -> record the retry (JobRetry history) + mark_retrying + re-enqueue
#   otherwise
#     -> permanently fail the Job with a recorded error type + message
#
# Retry policy (see JobFailureClassifier):
#   - retry:  Docker failure, worker crash, network timeout
#   - no retry: assertion failures, browser test failures, application bugs
# Maximum automatic retries: config/executehub.yml -> max_job_retries (default 3).
#
# Re-enqueueing is done through TestExecutionWorker (the same queue) so a
# retried job is picked up by any available worker, preserving load balancing.
class JobRetrier
  def self.call(job, error, type: nil)
    new(job, error, type: type).call
  end

  def initialize(job, error, type: nil)
    @job = job
    @error = error
    @classification = JobFailureClassifier.call(error, type: type)
  end

  def call
    if @classification.retryable? && retries_remaining?
      retry_job
    else
      give_up
    end
  end

  private

  # Records the retry history, bumps retry_count via mark_retrying!, and puts
  # the job back on the queue. The job is NOT marked failed — it stays alive.
  def retry_job
    @job.record_retry!(reason: @classification.reason, error_message: error_message)
    TestExecutionWorker.perform_in(retry_delay, @job.id)
    log(:warn, "Retryable failure (#{@classification.reason}) — retry #{@job.retry_count}/#{max_retries}")
    :retried
  end

  def give_up
    @job.update!(error_message: error_message, error_type: @classification.reason)
    @job.mark_failed!
    log(:error, "Job failed permanently (#{@classification.reason}): #{error_message}")
    :failed
  end

  def retries_remaining?
    @job.retry_count < max_retries
  end

  def max_retries
    Rails.configuration.executehub.fetch("max_job_retries", 3).to_i
  end

  def retry_delay
    Rails.configuration.executehub.fetch("retry_delay_seconds", 5).to_i
  end

  def error_message
    @error.respond_to?(:message) ? @error.message.to_s : @error.to_s
  end

  def log(level, message)
    return if message.blank?

    ExecutionLog.create!(job: @job, level: level, message: message)
  end
end
