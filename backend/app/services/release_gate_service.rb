# ReleaseGateService decides whether a finished TestRun makes a release safe.
# It is the core of the deployment gate. Rules, evaluated in order:
#
#   1. TestRun is not complete         -> BLOCK
#   2. A critical test failed          -> BLOCK   (failed test from a required suite)
#   3. Required suite did not run      -> BLOCK
#   4. Success rate below threshold    -> BLOCK
#   5. otherwise                       -> APPROVED
#
# Thresholds come from the project's release_policy (jsonb):
#
#   {
#     "minimum_success_rate": 95,
#     "required_suites": ["smoke", "regression"]
#   }
#
# Global defaults (config/executehub.yml -> release_gate) apply when a key is
# absent. The service is pure logic: it never mutates records and never talks
# to Jenkins.
class ReleaseGateService
  # Immutable evaluation result.
  class Result
    attr_reader :status, :reason

    def initialize(status:, reason: nil)
      @status = status
      @reason = reason
    end

    def approved?
      @status == :approved
    end

    def blocked?
      @status == :blocked
    end

    def to_h
      { status: @status, reason: @reason, approved: approved? }
    end
  end

  def self.call(test_run)
    new(test_run).call
  end

  def initialize(test_run)
    @test_run = test_run
    @project = test_run.project
  end

  def call
    return block("TestRun is incomplete (status: #{@test_run.status})") unless complete?

    critical = critical_failures
    if critical.any?
      return block("Critical test(s) failed: #{critical_names(critical)}")
    end

    missing = missing_required_suites
    return block("Required suite(s) did not run: #{missing.join(', ')}") if missing.any?

    if success_rate < minimum_success_rate
      return block("Success rate #{success_rate}% is below the required #{minimum_success_rate}%")
    end

    Result.new(status: :approved)
  end

  # Policy accessors exposed for specs/consistency.
  def minimum_success_rate
    policy_value(:minimum_success_rate).to_f
  end

  def required_suites
    Array(policy_value(:required_suites)).map(&:to_s)
  end

  def policy
    @policy ||= begin
      # Rails.configuration.executehub is an OrderedOptions whose nested values
      # are symbol-keyed hashes; #[] is key-indifferent, #fetch is not.
      defaults = Rails.configuration.executehub[:release_gate].to_h.with_indifferent_access
      defaults.merge((@project.release_policy || {}).with_indifferent_access)
    end
  end

  def policy_value(key)
    policy[key.to_s] || policy[key.to_sym]
  end

  private

  def complete?
    @test_run.status == "completed" && @test_run.finished_at.present? && @test_run.test_report.present?
  end

  # A failed test is "critical" when its suite is on the project's required
  # list — those are the flows a release must never break.
  def critical_failures
    return [] if required_suites.empty?

    @test_run.test_results.where(
      status: "failed", suite_name: required_suites
    ).limit(10)
  end

  def critical_names(results)
    results.map { |r| r.test_name.to_s }.compact.first(3).join(", ")
  end

  # Required suites that never executed as part of this run (not in the run's
  # suite and not seen in any test result).
  def missing_required_suites
    ran = suites_that_ran
    required_suites.reject { |suite| ran.include?(suite) }
  end

  def suites_that_ran
    suites = @test_run.test_results.distinct.pluck(:suite_name).compact
    suites << @test_run.test_suite&.name
    suites.compact.map(&:to_s).uniq
  end

  # Percentage of executed tests that passed. Uses the aggregated report when
  # present to avoid re-scanning every TestResult.
  def success_rate
    report = @test_run.test_report
    executed = report ? report.passed_tests.to_i + report.failed_tests.to_i
                      : @test_run.passed_tests.to_i + @test_run.failed_tests.to_i
    return 0.0 if executed.zero?

    passed = report ? report.passed_tests.to_i : @test_run.passed_tests.to_i
    (passed.to_f / executed * 100).round(2)
  end

  def block(reason)
    Result.new(status: :blocked, reason: reason)
  end
end