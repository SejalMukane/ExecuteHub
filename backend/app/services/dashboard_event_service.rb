# DashboardEventService is the single source of every Action Cable broadcast.
# Controllers, workers and other services never broadcast directly; they call
# one of the helpers below. This keeps payload shapes, stream names and failure
# handling in one place and lets the frontend reason about a small, typed event
# vocabulary.
#
# Streams:
#   dashboard               -> global overview, activity, alerts
#   test_run_<id>           -> progress + job lifecycle for one run
#   workers                 -> worker pool heartbeats and status transitions
#   queue                   -> queue depth and throughput events
#
# Every broadcast is fire-and-forget: a missing/down cable server must never
# break execution logic.
class DashboardEventService
  class << self
    # ----------------------------------------------------------------------
    # Test Run events
    # ----------------------------------------------------------------------
    def test_run_started(test_run)
      broadcast_test_run(:test_run_started, test_run)
      broadcast_progress(:test_run_progress_updated, test_run)
      broadcast_queue_updated
    end

    def test_run_progress_updated(test_run)
      broadcast_progress(:test_run_progress_updated, test_run)
    end

    def test_run_completed(test_run)
      broadcast_test_run(:test_run_completed, test_run)
      broadcast_progress(:test_run_progress_updated, test_run)
      broadcast_queue_updated
      broadcast_dashboard(:execution_finished, execution_payload(test_run))
    end

    # ----------------------------------------------------------------------
    # Job events
    # ----------------------------------------------------------------------
    def job_created(job)
      broadcast_job(:job_created, job)
      broadcast_test_run(:test_run_progress_updated, job.test_run)
      broadcast_queue_updated
    end

    def job_started(job)
      broadcast_job(:job_started, job)
      broadcast_test_run(:test_run_progress_updated, job.test_run)
      broadcast_queue_updated
    end

    def job_completed(job)
      broadcast_job(:job_completed, job)
      broadcast_test_run(:test_run_progress_updated, job.test_run)
      broadcast_queue_updated
    end

    def job_failed(job)
      broadcast_job(:job_failed, job)
      broadcast_test_run(:test_run_progress_updated, job.test_run)
      broadcast_queue_updated
    end

    # ----------------------------------------------------------------------
    # Worker events
    # ----------------------------------------------------------------------
    def worker_registered(worker)
      broadcast_worker(:worker_registered, worker)
    end

    def worker_heartbeat(worker)
      broadcast_worker(:worker_heartbeat, worker)
    end

    def worker_online(worker)
      broadcast_worker(:worker_online, worker)
    end

    def worker_offline(worker)
      broadcast_worker(:worker_offline, worker)
    end

    # ----------------------------------------------------------------------
    # Queue / execution events
    # ----------------------------------------------------------------------
    def queue_updated(stats = nil)
      broadcast_queue_updated(stats)
    end

    def artifacts_uploaded(job, artifact_count)
      payload = {
        job_id: job.id,
        test_run_id: job.test_run_id,
        artifact_count: artifact_count,
        worker_id: job.worker_id
      }
      broadcast("test_run_#{job.test_run_id}", { type: :artifacts_uploaded, artifacts: payload })
      broadcast("dashboard", { type: :artifacts_uploaded, artifacts: payload })
    end

    # ----------------------------------------------------------------------
    # Artifact upload lifecycle events (Part 22)
    # ----------------------------------------------------------------------
    def artifact_upload_started(artifact)
      artifact_broadcast(:artifact_upload_started, artifact)
    end

    def artifact_uploaded(artifact)
      artifact_broadcast(:artifact_uploaded, artifact)
    end

    def artifact_failed(artifact, error_message)
      payload = { type: :artifact_failed, error: error_message, artifact: artifact_payload(artifact) }
      broadcast("test_run_#{artifact.test_run_id}", payload)
      broadcast("dashboard", payload)
    end

    # ----------------------------------------------------------------------
    # Report / result events (Part 22)
    # ----------------------------------------------------------------------
    def report_generated(test_run)
      payload = {
        type: :report_generated,
        test_run_id: test_run.id,
        report: report_payload(test_run.test_report)
      }
      broadcast("test_run_#{test_run.id}", payload)
      broadcast("dashboard", payload)
    end

    def test_result_completed(test_result)
      payload = { type: :test_result_completed, test_result: test_result_payload(test_result) }
      broadcast("test_run_#{test_result.test_run_id}", payload)
      broadcast("dashboard", payload)
    end

    def test_run_analytics_updated(test_run)
      payload = { type: :test_run_analytics_updated, test_run_id: test_run.id }
      broadcast("test_run_#{test_run.id}", payload)
      broadcast("dashboard", payload)
    end

    def execution_finished(test_run)
      broadcast_dashboard(:execution_finished, execution_payload(test_run))
    end

    # ----------------------------------------------------------------------
    # Generic primitives — used by the helpers above and by metrics services.
    # ----------------------------------------------------------------------
    def broadcast_progress(kind, test_run)
      broadcast("test_run_#{test_run.id}", {
        type: kind,
        test_run: test_run_progress_payload(test_run)
      })
      broadcast("dashboard", {
        type: kind,
        test_run: test_run_progress_payload(test_run)
      })
    end

    def broadcast_worker(kind, worker)
      payload = { type: kind, worker: worker_payload(worker) }
      broadcast("workers", payload)
      broadcast("dashboard", payload)
    end

    def broadcast_queue(stats = nil)
      stats ||= QueueMetrics.call
      payload = { type: :queue_updated, queue: stats }
      broadcast("queue", payload)
      broadcast("dashboard", payload)
    end

    def broadcast_test_run(kind, test_run)
      payload = { type: kind, test_run: test_run_full_payload(test_run) }
      broadcast("test_run_#{test_run.id}", payload)
      broadcast("dashboard", payload)
    end

    def broadcast_metrics
      metrics = DashboardMetrics.call
      queue = QueueMetrics.call
      broadcast_dashboard(:metrics_updated, {
        metrics: metrics,
        queue: queue
      })
    rescue StandardError => e
      Rails.logger.warn("[DashboardEventService] Metrics broadcast failed: #{e.message}")
    end

    def metrics_snapshot
      {
        type: :metrics_updated,
        metrics: DashboardMetrics.call,
        queue: QueueMetrics.call
      }
    end

    def broadcast_dashboard(kind, payload = {})
      broadcast("dashboard", { type: kind, **payload })
    end

    private

    def broadcast(stream, payload)
      ActionCable.server.broadcast(stream, payload)
    rescue StandardError => e
      Rails.logger.warn("[DashboardEventService] Broadcast to #{stream} failed: #{e.message}")
    end

    def broadcast_queue_updated(stats = nil)
      broadcast_queue(stats)
    end

    def broadcast_job(kind, job)
      payload = { type: kind, job: job_payload(job) }
      broadcast("jobs", payload)
      broadcast("job_#{job.id}", payload)
      broadcast("test_run_#{job.test_run_id}", payload)
    end

    # ----------------------------------------------------------------------
    # Payload builders
    # ----------------------------------------------------------------------
    def test_run_progress_payload(test_run)
      test_run.progress_snapshot.merge(
        project_name: test_run.project.name
      )
    end

    def test_run_full_payload(test_run)
      test_run.progress_snapshot.merge(
        project_id: test_run.project_id,
        project_name: test_run.project.name,
        branch: test_run.branch,
        commit_sha: test_run.commit_sha,
        test_suite_name: test_run.test_suite&.name
      )
    end

    def worker_payload(worker)
      job = worker.current_job
      {
        id: worker.id,
        worker_name: worker.worker_name,
        status: worker.status,
        last_seen_at: worker.last_seen_at,
        heartbeat_at: worker.last_seen_at,
        cpu_usage: worker.cpu_usage,
        memory_usage: worker.memory_usage,
        execution_count: worker.execution_count,
        current_job_id: worker.current_job_id,
        current_job: job && current_job_payload(job),
        browser: current_browser_for(job),
        container_status: job ? (job.container_id.present? ? "running" : "scheduled") : nil
      }
    end

    def current_job_payload(job)
      {
        id: job.id,
        test_run_id: job.test_run_id,
        chunk_number: job.chunk_number,
        test_count: job.test_count,
        status: job.status,
        container_id: job.container_id,
        started_at: job.started_at,
        duration_seconds: job.duration_seconds,
        worker_id: job.worker_id
      }
    end

    def current_browser_for(job)
      return "Chrome" unless job

      BrowserLabel.call
    end

    def job_payload(job)
      {
        id: job.id,
        test_run_id: job.test_run_id,
        worker_id: job.worker_id,
        chunk_number: job.chunk_number,
        test_count: job.test_count,
        status: job.status,
        started_at: job.started_at,
        finished_at: job.finished_at,
        retry_count: job.retry_count,
        container_id: job.container_id
      }
    end

    def artifact_broadcast(kind, artifact)
      payload = { type: kind, artifact: artifact_payload(artifact) }
      broadcast("test_run_#{artifact.test_run_id}", payload)
      broadcast("dashboard", payload)
    end

    def artifact_payload(artifact)
      {
        id: artifact.id,
        job_id: artifact.job_id,
        test_run_id: artifact.test_run_id,
        artifact_type: artifact.artifact_type,
        file_name: artifact.file_name,
        size: artifact.size,
        status: artifact.status
      }
    end

    def report_payload(report)
      return {} unless report

      {
        id: report.id,
        test_run_id: report.test_run_id,
        total_tests: report.total_tests,
        passed_tests: report.passed_tests,
        failed_tests: report.failed_tests,
        skipped_tests: report.skipped_tests,
        flaky_tests: report.flaky_tests,
        duration_ms: report.duration_ms,
        success_rate: report.success_rate,
        generated_at: report.generated_at
      }
    end

    def test_result_payload(result)
      {
        id: result.id,
        job_id: result.job_id,
        test_run_id: result.test_run_id,
        test_name: result.test_name,
        suite_name: result.suite_name,
        status: result.status,
        duration_ms: result.duration_ms,
        browser: result.browser,
        error_message: result.error_message,
        retry_count: result.retry_count
      }
    end

    def execution_payload(test_run)
      {
        test_run_id: test_run.id,
        project_id: test_run.project_id,
        project_name: test_run.project.name,
        status: test_run.status,
        passed_tests: test_run.passed_tests,
        failed_tests: test_run.failed_tests,
        total_duration_ms: test_run.total_duration_ms,
        progress_percentage: test_run.progress_percentage,
        finished_at: test_run.finished_at
      }
    end
  end
end
