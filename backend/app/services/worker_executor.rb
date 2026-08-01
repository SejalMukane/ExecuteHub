# WorkerExecutor runs a single Job inside an isolated Docker container and
# owns the whole execution lifecycle for that Job:
#
#   mark running
#     -> create container
#     -> start container
#     -> stream Playwright output into ExecutionLogs
#     -> mark uploading_artifacts
#     -> copy artifacts out of the container (docker cp)
#     -> parse the Playwright JSON report
#     -> persist Artifacts + execution summary
#     -> mark completed / failed (timestamps)
#     -> refresh TestRun progress
#     -> destroy the container (ensure)
#
# The class intentionally contains NO Sidekiq logic — TestExecutionWorker only
# decides *when* to run and delegates *how* to this service, keeping the worker
# reusable outside of background jobs.
#
# Separation of concerns:
#   - Docker primitives  -> DockerService (the only Docker-aware class)
#   - Storage layout     -> ArtifactStore
#   - Report parsing     -> PlaywrightOutputParser
#   - DB persistence     -> Job / ExecutionLog / Artifact models
class WorkerExecutor
  # Raised for recoverable execution problems (container/Docker failures,
  # missing artifact payloads) that should fail the Job.
  class ExecutionError < StandardError; end

  def self.execute(job)
    new(job).execute
  end

  attr_reader :job

  def initialize(job, docker: DockerService.new, parser: PlaywrightOutputParser, artifact_store: ArtifactStore)
    @job = job
    @docker = docker
    @parser = parser
    @artifact_store = artifact_store
    @summary = nil
    @exit_code = nil
  end

  def execute
    container = nil
    job.mark_running!
    log(:info, "Starting execution for Job ##{job.id}")

    container = create_container
    job.update!(container_id: container.id)
    log(:info, "Container created (#{container.id})")

    docker.start(container)
    log(:info, "Container started")

    run_playwright(container)

    upload_artifacts(container)

    finish_job
  rescue StandardError => e
    fail_job(e)
  ensure
    destroy_container(container)
    job
  end

  private

  def run_playwright(container)
    log(:info, "Running Playwright tests")
    docker.stream_logs(container) { |line| log(:info, clean(line)) }
    @exit_code = docker.exit_code(container)
    log(:info, "Playwright finished (exit code #{@exit_code})")
  end

  def upload_artifacts(container)
    job.mark_uploading_artifacts!
    log(:info, "Uploading artifacts")

    job_dir = @artifact_store.prepare(job)
    @docker.copy(container, source: settings["container_artifacts_path"], destination: job_dir)

    results_file = job_dir.join("artifacts", settings["results_file"])
    @summary = @parser.parse(results_file, job_dir)

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
      job.update!(
        passed_tests: @summary[:passed],
        failed_tests: @summary[:failed],
        duration_ms: duration_ms,
        error_message: "Playwright reported #{@summary[:failed]} failed test(s)"
      )
      job.mark_failed!
      log(:warn, "Execution finished with test failures")
    end

    TestRunProgressUpdater.call(job.test_run)
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

  def fail_job(error)
    log(:error, "Job failed: #{error.message}")
    job.update!(error_message: error.message)
    job.mark_failed!
    TestRunProgressUpdater.call(job.test_run)
  end

  def destroy_container(container)
    return unless container

    @docker.destroy(container)
    log(:info, "Container removed")
  rescue StandardError => e
    log(:error, "Failed to remove container: #{e.message}")
  end

  def log(level, message)
    ExecutionLog.create!(job: job, level: level, message: message)
    Rails.logger.info("[WorkerExecutor] Job ##{job.id}: #{message}") if level == "info"
    Rails.logger.warn("[WorkerExecutor] Job ##{job.id}: #{message}") if level == "warn"
    Rails.logger.error("[WorkerExecutor] Job ##{job.id}: #{message}") if level == "error"
  end

  # Removes ANSI colour/format escape codes so stored logs render cleanly.
  def clean(line)
    line.gsub(/\e\[[0-9;]*m/, "")
  end

  def settings
    Rails.configuration.executehub.fetch("worker", {})
  end
end
