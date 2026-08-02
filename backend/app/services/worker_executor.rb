# WorkerExecutor runs a single Job inside an isolated Docker container and
# owns the whole execution lifecycle for that Job:
#
#   mark running
#     -> create container
#     -> start container
#     -> stream Playwright output into ExecutionLogs (with a timeout watchdog)
#     -> mark uploading_artifacts
#     -> copy artifacts out of the container (docker cp)
#     -> parse the Playwright JSON report
#     -> persist Artifacts + execution summary
#     -> mark completed / failed (timestamps)
#     -> refresh TestRun progress
#     -> destroy the container (ensure)
#
# Failure handling (Part 5):
#   - infrastructure failures (Docker, network) are routed through JobRetrier,
#     which retries retryable errors and permanently fails the rest
#   - assertion / browser test failures never retry — they fail immediately
#   - an execution timeout kills the container and fails the Job
#   - a failing Job NEVER stops other Jobs: every Job runs independently
#
# The class intentionally contains NO Sidekiq logic — TestExecutionWorker only
# decides *when* to run and delegates *how* to this service, keeping the worker
# reusable outside of background jobs.
#
# Separation of concerns:
#   - Docker primitives  -> DockerService (the only Docker-aware class)
#   - Storage layout     -> ArtifactStore
#   - Report parsing     -> PlaywrightOutputParser
#   - Failure policy     -> JobRetrier / JobFailureClassifier
#   - DB persistence     -> Job / ExecutionLog / Artifact models
class WorkerExecutor
  # Raised for recoverable execution problems (container/Docker failures,
  # missing artifact payloads) that should fail the Job.
  class ExecutionError < StandardError; end

  # Raised when a Job's container runs longer than worker_execution_timeout_seconds.
  class ExecutionTimeoutError < StandardError; end

  def self.execute(job, worker: nil)
    new(job, worker: worker).execute
  end

  attr_reader :job, :worker

  def initialize(job, docker: DockerService.new, parser: PlaywrightOutputParser, artifact_store: ArtifactStore, worker: nil)
    @job = job
    @docker = docker
    @parser = parser
    @artifact_store = artifact_store
    @worker = worker
    @summary = nil
    @exit_code = nil
  end

  def execute
    container = nil
    job.mark_running!
    RealtimeBroadcaster.job_started(job)
    log(:info, "Starting execution for Job ##{job.id}")

    container = create_container
    job.update!(container_id: container.id)
    log(:info, "Container created (#{container.id})")

    @docker.start(container)
    log(:info, "Container started")

    run_playwright_with_timeout(container)

    upload_artifacts(container)

    finish_job
  rescue StandardError => e
    fail_job(e)
  ensure
    destroy_container(container)
    job
  end

  private

  # Streams Playwright output while watching a wall-clock budget. If the
  # container runs past the timeout the container is killed and the Job fails
  # with ExecutionTimeoutError (never retried — see JobFailureClassifier).
  def run_playwright_with_timeout(container)
    log(:info, "Running Playwright tests")
    thread = Thread.new do
      @docker.stream_logs(container) { |line| log(:info, clean(line)) }
    rescue StandardError => e
      Rails.logger.warn("[WorkerExecutor] Log stream ended early: #{e.message}")
    end

    if thread.join(timeout_seconds).nil?
      log(:error, "Execution exceeded #{timeout_seconds}s timeout — terminating container")
      @docker.destroy(container)
      raise ExecutionTimeoutError, "Execution exceeded #{timeout_seconds}s timeout"
    end

    @exit_code = @docker.exit_code(container)
    log(:info, "Playwright finished (exit code #{@exit_code})")
  end

  def upload_artifacts(container)
    job.mark_uploading_artifacts!
    log(:info, "Uploading artifacts")

    job_dir = @artifact_store.prepare(job)
    @docker.copy(container, source: settings["container_artifacts_path"], destination: job_dir)

    output_dir = job_dir.join("artifacts")
    results_file = output_dir.join(settings["results_file"])
    @summary = @parser.parse(results_file, output_dir)

    persist_summary
    persist_artifacts

    log(:info, "Execution summary: #{@summary[:passed]} passed, #{@summary[:failed]} failed")
  rescue DockerService::DockerError, Errno::ENOENT => e
    log(:error, "Artifact upload failed: #{e.message}")
    raise ExecutionError, "Artifact upload failed: #{e.message}"
  end

  def finish_job
    duration_ms = ((Time.current - job.started_at) * 1000).round

    if job_succeeded?
      job.update!(
        passed_tests: @summary[:passed],
        failed_tests: @summary[:failed],
        duration_ms: duration_ms
      )
      job.mark_completed!
      log(:info, "Execution finished")
    else
      # Assertion / browser test failures are NOT retried — they fail now.
      job.update!(
        passed_tests: @summary[:passed],
        failed_tests: @summary[:failed],
        duration_ms: duration_ms,
        error_message: "Playwright reported #{@summary[:failed]} failed test(s)",
        error_type: "test_failure"
      )
      job.mark_failed!
      log(:warn, "Execution finished with test failures")
    end

    TestRunProgressUpdater.call(job.test_run)
    RealtimeBroadcaster.job_finished(job)
  end

  def job_succeeded?
    @exit_code == 0 && @summary && @summary[:failed].zero?
  end

  def create_container
    log(:info, "Creating Docker container (image #{settings["image"]})")
    @docker.create(
      name: container_name,
      image: settings["image"],
      command: settings["command"],
      workdir: settings["container_workdir"]
    )
  end

  def container_name
    "executehub-job-#{job.id}-#{SecureRandom.hex(4)}"
  end

  # Routes an execution failure through JobRetrier: retryable infra errors are
  # retried (up to max_job_retries), everything else fails permanently. The
  # failure is logged and progress is refreshed so the run keeps moving — one
  # failed worker never stops the other Jobs.
  def fail_job(error)
    log(:error, "Job failed: #{error.message}")
    JobRetrier.call(job, error)
    TestRunProgressUpdater.call(job.test_run)
    # Only terminal failures broadcast "finished" — a retried job will start
    # again (and broadcast job_started) once it is re-dispatched.
    RealtimeBroadcaster.job_finished(job) if job.failed?
  end

  def persist_summary
    job.update!(
      passed_tests: @summary[:passed],
      failed_tests: @summary[:failed],
      duration_ms: @summary[:duration_ms]
    )
  end

  def persist_artifacts
    records = @summary[:screenshots].map { |path| artifact_attributes("screenshot", path) } +
              @summary[:videos].map { |path| artifact_attributes("video", path) } +
              @summary[:traces].map { |path| artifact_attributes("trace", path) }
    job.artifacts.create!(records) if records.any?
  end

  def artifact_attributes(type, path)
    {
      artifact_type: type,
      path: @artifact_store.relative(path),
      size: File.size?(path).to_i
    }
  end

  def destroy_container(container)
    return unless container

    @docker.destroy(container)
    log(:info, "Container removed")
  rescue StandardError => e
    log(:error, "Failed to remove container: #{e.message}")
  end

  def log(level, message)
    return if message.blank?

    ExecutionLog.create!(job: job, level: level, message: message)
    worker_label = worker ? " [#{worker.worker_name}]" : ""
    Rails.logger.info("[WorkerExecutor] Job ##{job.id}#{worker_label}: #{message}") if level == "info"
    Rails.logger.warn("[WorkerExecutor] Job ##{job.id}#{worker_label}: #{message}") if level == "warn"
    Rails.logger.error("[WorkerExecutor] Job ##{job.id}#{worker_label}: #{message}") if level == "error"
  end

  # Removes ANSI colour/format escape codes so stored logs render cleanly.
  def clean(line)
    line.gsub(/\e\[[0-9;]*m/, "")
  end

  # executehub.yml is loaded into ActiveSupport::OrderedOptions: the top-level
  # [] access is key-indifferent, but nested values are plain symbol-keyed
  # Hashes. with_indifferent_access lets us read string keys everywhere.
  def settings
    @settings ||= (Rails.configuration.executehub["worker"] || {}).with_indifferent_access
  end

  def timeout_seconds
    Rails.configuration.executehub.fetch("worker_execution_timeout_seconds", 600).to_i
  end
end
