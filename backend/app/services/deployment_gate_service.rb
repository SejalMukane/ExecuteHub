# DeploymentGateService evaluates the release gate for a finished CI TestRun
# and reflects the outcome on the Pipeline. It runs once the TestRun reaches a
# terminal state (completed or failed) and a Pipeline exists (CI-triggered runs
# only — manual runs have no gate).
#
# Decision flow:
#   failed run                          -> gate BLOCKED, pipeline BLOCKED
#   ReleaseGateService blocked          -> gate BLOCKED, pipeline BLOCKED
#   approved + requires_manual_approval -> gate stays PENDING (human approval)
#   approved + auto-approve             -> gate APPROVED, pipeline PASSED
#
# The Jenkins build description is updated with the outcome (best-effort: a
# Jenkins outage or read-only token must never break the pipeline).
class DeploymentGateService
  Result = Struct.new(:gate, :applied, keyword_init: true)

  def self.evaluate(test_run)
    new(test_run).evaluate
  end

  def initialize(test_run)
    @test_run = test_run
    @pipeline = test_run.pipeline
  end

  def evaluate
    return Result.new(gate: nil, applied: false) unless @pipeline
    return Result.new(gate: nil, applied: false) unless @test_run.terminal?

    gate = find_or_create_gate
    decision = decide
    apply_decision(gate, decision)
    notify_jenkins(gate)

    Result.new(gate: gate, applied: true)
  end

  private

  def decide
    return ReleaseGateService::Result.new(status: :blocked, reason: "Test run failed") if @test_run.status == "failed"

    ReleaseGateService.call(@test_run)
  end

  def apply_decision(gate, decision)
    if decision.approved?
      if gate.requires_approval?
        gate.update!(status: :pending, decided_at: nil)
        @pipeline.update!(status: :running) unless @pipeline.terminal?
        DashboardEventService.deployment_gate_pending(gate)
        notify(title: "Deployment gate awaiting approval",
               description: "The release gate for #{@pipeline.name} passed its tests and is ready to approve.",
               category: :deployment_gate)
      else
        gate.approve!
        @pipeline.update!(status: :passed)
        DashboardEventService.deployment_gate_approved(gate)
        DashboardEventService.pipeline_completed(@pipeline)
        notify(title: "Pipeline passed",
               description: "#{@pipeline.name} passed its release gate and can be deployed.",
               category: :deployment_gate)
      end
    else
      gate.block!(decision.reason)
      @pipeline.update!(status: :blocked)
      DashboardEventService.deployment_gate_blocked(gate)
      DashboardEventService.pipeline_completed(@pipeline)
      notify(title: "Pipeline blocked",
             description: "#{@pipeline.name} was blocked: #{decision.reason}",
             category: :deployment_gate)
    end
  end

  def find_or_create_gate
    DeploymentGate.find_or_create_by!(pipeline: @pipeline) do |gate|
      gate.project = @pipeline.project
      gate.test_run = @test_run
      gate.requires_approval = requires_manual_approval?
    end.tap do |gate|
      gate.update!(test_run: @test_run)
    end
  end

  def requires_manual_approval?
    policy = (@pipeline.project.release_policy || {}).with_indifferent_access
    return policy[:requires_manual_approval] if policy.key?(:requires_manual_approval)

    Rails.configuration.executehub[:release_gate]
      .to_h.with_indifferent_access[:requires_manual_approval].to_s == "true"
  end

  # Best-effort: surface the ExecuteHub outcome inside Jenkins. Any failure
  # (auth, timeout, network) is logged and swallowed.
  def notify_jenkins(gate)
    build = @pipeline.builds.last
    return unless build

    JenkinsService.set_build_description(build.jenkins_build_number, jenkins_description(gate))
  rescue StandardError => e
    Rails.logger.warn("[DeploymentGateService] Jenkins notification failed: #{e.message}")
  end

  def jenkins_description(gate)
    report = @test_run.test_report
    rate = report&.success_rate ? "#{report.success_rate}% pass" : "no report"
    summary = "ExecuteHub: #{rate}"
    case gate.status
    when "approved" then "#{summary} — gate APPROVED"
    when "blocked" then "#{summary} — gate BLOCKED (#{gate.reason})"
    when "pending" then "#{summary} — awaiting approval"
    else summary
    end
  end

  # Best-effort: a notification failure (DB/broadcast) must never break the
  # gate decision or the pipeline transition already applied above.
  def notify(title:, description:, category:)
    NotificationService.notify(project: @pipeline.project, title: title,
                               description: description, category: category,
                               test_run: @test_run, pipeline: @pipeline)
  rescue StandardError => e
    Rails.logger.warn("[DeploymentGateService] Notification failed: #{e.message}")
  end
end
