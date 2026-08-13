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
    # CI / pipeline events (Week 8)
    # ----------------------------------------------------------------------
    def pipeline_created(pipeline)
      broadcast_pipeline(:pipeline_created, pipeline)
    end

    def pipeline_started(pipeline)
      broadcast_pipeline(:pipeline_started, pipeline)
    end

    def pipeline_completed(pipeline)
      broadcast_pipeline(:pipeline_completed, pipeline)
      broadcast_gate_for_pipeline(pipeline)
    end

    def build_started(build)
      broadcast_build(:build_started, build)
    end

    def build_completed(build)
      broadcast_build(:build_completed, build)
    end

    def test_run_started_for_ci(test_run)
      broadcast_pipeline(:test_run_started, test_run.pipeline) if test_run.pipeline
    end

    def deployment_gate_approved(gate)
      broadcast_gate(:deployment_gate_approved, gate)
    end

    def deployment_gate_blocked(gate)
      broadcast_gate(:deployment_gate_blocked, gate)
    end

    def deployment_gate_pending(gate)
      broadcast_gate(:deployment_gate_pending, gate)
    end

    def notification_created(notification)
      payload = { type: :notification_created, notification: notification_payload(notification) }
      broadcast("notifications_#{notification.project_id}", payload)
      broadcast("dashboard", payload)
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

    # ----------------------------------------------------------------------
    # CI payload builders
    # ----------------------------------------------------------------------
    def broadcast_pipeline(kind, pipeline)
      payload = { type: kind, pipeline: pipeline_payload(pipeline) }
      broadcast("pipeline_#{pipeline.id}", payload)
      broadcast("dashboard", payload)
    end

    def broadcast_build(kind, build)
      payload = { type: kind, build: build_payload(build) }
      broadcast("builds", payload)
      broadcast("pipeline_#{build.pipeline_id}", payload) if build.pipeline_id
      broadcast("dashboard", payload)
    end

    def broadcast_gate(kind, gate)
      payload = { type: kind, deployment_gate: gate_payload(gate) }
      broadcast("pipeline_#{gate.pipeline_id}", payload)
      broadcast("dashboard", payload)
    end

    def broadcast_gate_for_pipeline(pipeline)
      gate = pipeline.deployment_gate
      broadcast_gate(:deployment_gate_pending, gate) if gate&.pending?
    end

    def pipeline_payload(pipeline)
      {
        id: pipeline.id,
        project_id: pipeline.project_id,
        project_name: pipeline.project&.name,
        name: pipeline.name,
        provider: pipeline.provider,
        status: pipeline.status,
        branch: pipeline.branch,
        commit_sha: pipeline.commit_sha,
        triggered_by: pipeline.triggered_by,
        created_at: pipeline.created_at
      }
    end

    def build_payload(build)
      {
        id: build.id,
        pipeline_id: build.pipeline_id,
        test_run_id: build.test_run_id,
        project_id: build.project_id,
        jenkins_build_number: build.jenkins_build_number,
        jenkins_job_name: build.jenkins_job_name,
        branch: build.branch,
        commit_sha: build.commit_sha,
        status: build.status,
        started_at: build.started_at,
        finished_at: build.finished_at,
        duration: build.duration
      }
    end

    def gate_payload(gate)
      {
        id: gate.id,
        pipeline_id: gate.pipeline_id,
        test_run_id: gate.test_run_id,
        project_id: gate.project_id,
        status: gate.status,
        reason: gate.reason,
        requires_approval: gate.requires_approval,
        decided_at: gate.decided_at,
        created_at: gate.created_at
      }
    end

    def notification_payload(notification)
      {
        id: notification.id,
        project_id: notification.project_id,
        test_run_id: notification.test_run_id,
        pipeline_id: notification.pipeline_id,
        title: notification.title,
        description: notification.description,
        category: notification.category,
        read: notification.read?,
        created_at: notification.created_at
      }
    end
  end
end
