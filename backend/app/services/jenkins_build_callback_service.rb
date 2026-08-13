# JenkinsBuildCallbackService applies a Jenkins webhook/result to a Build and
# its Pipeline. It is idempotent: re-delivered webhooks for an already-terminal
# Build are no-ops (applied: false) so retries never re-fire transitions.
#
# The controller (not this service) is responsible for authenticating the
# request (shared secret) and locating the Build. Here we only translate the
# Jenkins status vocabulary into ExecuteHub Build/Pipeline states.
class JenkinsBuildCallbackService
  Result = Struct.new(:build, :applied, keyword_init: true)

  # Accepts both Jenkins's own result strings and ExecuteHub's normalized ones.
  STATUS_MAP = {
    "running" => :running,
    "started" => :running,
    "building" => :running,
    "success" => :passed,
    "passed" => :passed,
    "failure" => :failed,
    "unstable" => :failed,
    "failed" => :failed,
    "aborted" => :cancelled,
    "cancelled" => :cancelled,
    "not_built" => :error,
    "error" => :error
  }.freeze

  def self.call(build:, jenkins_status:)
    new(build, jenkins_status).call
  end

  def initialize(build, jenkins_status)
    @build = build
    @jenkins_status = jenkins_status.to_s.downcase
  end

  def call
    target = STATUS_MAP.fetch(@jenkins_status, :error)

    return Result.new(build: @build, applied: false) if already_in_state?(target)

    apply(target)
    Result.new(build: @build, applied: true)
  end

  private

  def already_in_state?(target)
    @build.status == target.to_s && @build.terminal?
  end

  def apply(target)
    if target == :running
      @build.mark_running!
      DashboardEventService.build_started(@build)
      mark_pipeline_running
    else
      @build.finish!(target)
      DashboardEventService.build_completed(@build)
      handle_terminal_result(target)
    end
  end

  # A failed/cancelled Jenkins build means the test run can no longer succeed.
  # We reflect that in the Pipeline (and cancel an in-flight TestRun) so the
  # pipeline reaches a terminal state even if no callback for the run arrives.
  def handle_terminal_result(target)
    case target
    when :passed
      # Build succeeded; the Pipeline only finishes when the TestRun completes
      # (see ResultAggregator/DeploymentGate). Leave everything running.
    when :failed, :error
      cancel_in_flight_run
      mark_pipeline_failed
    when :cancelled
      cancel_in_flight_run
      mark_pipeline_cancelled
    end
  end

  def mark_pipeline_running
    pipeline = @build.pipeline
    pipeline&.update!(status: :running)
    DashboardEventService.pipeline_started(pipeline) if pipeline
  end

  def mark_pipeline_failed
    pipeline = @build.pipeline
    pipeline&.update!(status: :failed)
    if pipeline
      DashboardEventService.pipeline_completed(pipeline)
      notify(title: "Pipeline failed",
             description: "#{pipeline.name} failed on Jenkins build ##{@build.jenkins_build_number}.")
    end
  end

  def mark_pipeline_cancelled
    pipeline = @build.pipeline
    pipeline&.update!(status: :cancelled)
    if pipeline
      DashboardEventService.pipeline_completed(pipeline)
      notify(title: "Pipeline cancelled",
             description: "#{pipeline.name} was cancelled on Jenkins build ##{@build.jenkins_build_number}.")
    end
  end

  # Best-effort: a notification failure (DB/broadcast) must never roll back the
  # applied pipeline transition or make the webhook respond 500 — Jenkins will
  # retry, and idempotency makes the retry harmless.
  def notify(title:, description:)
    NotificationService.notify(project: @build.pipeline.project, title: title,
                               description: description, category: :pipeline,
                               pipeline: @build.pipeline, test_run: @build.test_run)
  rescue StandardError => e
    Rails.logger.warn("[JenkinsBuildCallbackService] Notification failed: #{e.message}")
  end

  def cancel_in_flight_run
    test_run = @build.test_run
    return unless test_run
    return if %w[completed failed cancelled].include?(test_run.status)

    test_run.update!(status: :cancelled, finished_at: Time.current)
  end
end
