# TestAnalyticsService answers analytics questions with database aggregation
# queries only — it never loads historical TestResult/TestRun rows into memory
# (Part 13-14). It supports two scopes:
#
#   TestAnalyticsService.for_test_run(test_run)   -> one run's metrics
#   TestAnalyticsService.for_project(project)     -> historical analytics
#   TestAnalyticsService.global                   -> across everything
#
# All returned hashes are JSON-serializable and grouped by calendar day for the
# time-series charts.
class TestAnalyticsService
  TERMINAL_STATUSES = %w[completed failed].freeze

  def self.for_test_run(test_run)
    new(scope: TestRun.where(id: test_run.id)).full
  end

  def self.for_project(project, days: 30)
    new(scope: TestRun.where(project: project).where("created_at >= ?", days.days.ago), days: days).full
  end

  def self.global(days: 30)
    new(scope: TestRun.where("created_at >= ?", days.days.ago), days: days).full
  end

  def initialize(scope: TestRun.all, days: 30)
    @scope = scope
    @days = days
  end

  def full
    { overview: overview, history: history }
  end

  def overview
    counts = test_result_counts
    total = counts.values.sum
    passed = counts.fetch("passed", 0)
    failed = counts.fetch("failed", 0)

    completed = terminal_runs.completed.count
    run_total = terminal_runs.count

    {
      success_rate: percentage(passed, total),
      failure_rate: percentage(failed, total),
      average_execution_duration_ms: average_execution_duration_ms,
      average_test_duration_ms: average_test_duration_ms,
      tests_executed: total,
      tests_passed: passed,
      tests_failed: failed,
      tests_skipped: counts.fetch("skipped", 0),
      flaky_test_count: counts.fetch("flaky", 0),
      retry_rate: retry_rate,
      worker_utilization: worker_utilization,
      total_test_runs: run_total,
      completed_test_runs: completed,
      failed_test_runs: run_total - completed
    }
  end

  def history
    {
      success_rate_over_time: daily_aggregate("success_rate"),
      failure_rate_over_time: daily_aggregate("failure_rate"),
      average_execution_duration: daily_aggregate("average_duration"),
      tests_executed_per_day: daily_aggregate("tests"),
      flaky_tests: flaky_test_count,
      most_failing_tests: most_failing("test_name"),
      most_failing_suites: most_failing("suite_name")
    }
  end

  private

  def test_result_counts
    TestResult.where(test_run_id: @scope.select(:id)).group(:status).count
  end

  def flaky_test_count
    TestResult.where(test_run_id: @scope.select(:id)).flaky.count
  end

  def terminal_runs
    @scope.where(status: TERMINAL_STATUSES)
  end

  def average_execution_duration_ms
    avg = terminal_runs.where.not(total_duration_ms: nil).average(:total_duration_ms)
    avg && avg.round(2)
  end

  def average_test_duration_ms
    avg = TestResult.where(test_run_id: @scope.select(:id)).average(:duration_ms)
    avg && avg.round(2)
  end

  def retry_rate
    jobs = Job.where(test_run_id: @scope.select(:id))
    total = jobs.count
    return 0.0 if total.zero?

    retried = jobs.where("retry_count > 0").count
    percentage(retried, total)
  end

  def worker_utilization
    total = WorkerHeartbeat.count
    return 0.0 if total.zero?

    busy = WorkerHeartbeat.busy.count
    percentage(busy, total)
  end

  # One aggregation per calendar day. `metric` controls which SQL aggregate to
  # compute, all summed/across the day's terminal runs.
  def daily_aggregate(metric)
    select_map = {
      "tests" => "SUM(total_tests) AS value",
      "success_rate" => "SUM(passed_tests) AS passed, SUM(passed_tests) + SUM(failed_tests) AS total",
      "failure_rate" => "SUM(failed_tests) AS failed, SUM(passed_tests) + SUM(failed_tests) AS total",
      "average_duration" => "AVG(total_duration_ms) AS value"
    }.fetch(metric)

    rows = terminal_runs
    rows = rows.where.not(total_duration_ms: nil) if metric == "average_duration"

    aggregates = rows
      .group("DATE(created_at)")
      .select("DATE(created_at) AS day, #{select_map}")
      .order("day")

    case metric
    when "success_rate"
      aggregates.map { |r| { date: r.day.to_s, success_rate: percentage(r.passed, r.total) } }
    when "failure_rate"
      aggregates.map { |r| { date: r.day.to_s, failure_rate: percentage(r.failed, r.total) } }
    when "tests"
      aggregates.map { |r| { date: r.day.to_s, tests_executed: (r.value || 0).to_i } }
    when "average_duration"
      aggregates.map { |r| { date: r.day.to_s, average_execution_duration_ms: r.value&.round(2) } }
    end
  end

  def most_failing(column)
    TestResult
      .where(test_run_id: @scope.select(:id), status: "failed")
      .where.not(column => nil)
      .group(column)
      .select("#{column} AS name, COUNT(*) AS count")
      .order("count DESC")
      .limit(10)
      .map { |row| { name: row.name, count: row.count } }
  end

  def percentage(numerator, denominator)
    return 0.0 if denominator.zero?

    ((numerator.to_f / denominator) * 100).round(1)
  end
end
