# TestResultBuilder turns the per-test rows parsed from Playwright's JSON
# report into TestResult records (Part 9-10). It runs inside WorkerExecutor
# after the report is parsed, so every failed test automatically becomes the
# primary debugging object (error message, stack trace, browser, retry count,
# worker attribution via the Job).
class TestResultBuilder
  class << self
    def persist(job, tests, browser:)
      new(job, tests, browser: browser).persist
    end
  end

  def initialize(job, tests, browser:)
    @job = job
    @tests = Array(tests)
    @browser = browser
  end

  def persist
    return 0 if @tests.empty?

    records = @tests.map { |test| test_attributes(test) }
    persisted = @job.test_results.create!(records)
    Array(persisted).each { |result| DashboardEventService.test_result_completed(result) }
    Array(persisted).size
  end

  private

  def test_attributes(test)
    {
      test_run_id: @job.test_run_id,
      test_name: test[:title],
      suite_name: test[:file],
      status: test[:status],
      duration_ms: test[:duration_ms].to_i,
      browser: @browser,
      error_message: test[:error_message],
      stack_trace: test[:stack_trace],
      retry_count: test[:retry].to_i,
      started_at: test[:started_at],
      finished_at: finished_at(test)
    }
  end

  def finished_at(test)
    started = test[:started_at]
    return unless started

    started_time = started.is_a?(String) ? Time.iso8601(started) : started
    started_time + (test[:duration_ms].to_i / 1000.0)
  end
end
