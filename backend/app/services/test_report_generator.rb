# TestReportGenerator aggregates a TestRun's TestResults into the single
# aggregated TestReport row (Part 11). ResultAggregator invokes it once every
# Job is terminal, so a TestRun always ends up with exactly one report.
#
# If a run produced no parsed results (e.g. every job died on infrastructure
# failures), the report falls back to the Job-level counters so the run still
# has a meaningful, aggregated summary.
class TestReportGenerator
  class << self
    def call(test_run)
      new(test_run).call
    end
  end

  def initialize(test_run)
    @test_run = test_run
  end

  def call
    report = @test_run.test_report || @test_run.build_test_report
    report.assign_attributes(build_report)
    report.save!
    report
  end

  private

  def build_report
    counts = @test_run.test_results.group(:status).count
    total = counts.values.sum
    passed = counts.fetch("passed", 0)
    failed = counts.fetch("failed", 0)
    skipped = counts.fetch("skipped", 0)
    flaky = counts.fetch("flaky", 0)

    # Fallback when Playwright results were never parsed (infra failures).
    if total.zero?
      passed = @test_run.jobs.sum(:passed_tests)
      failed = @test_run.jobs.sum(:failed_tests)
      total = passed + failed
    end

    success_rate = total.zero? ? 0.0 : (passed.to_f / total * 100).round(1)

    {
      total_tests: total,
      passed_tests: passed,
      failed_tests: failed,
      skipped_tests: skipped,
      flaky_tests: flaky,
      duration_ms: @test_run.jobs.sum(:duration_ms),
      success_rate: success_rate,
      generated_at: Time.current
    }
  end
end
