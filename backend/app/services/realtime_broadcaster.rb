# RealtimeBroadcaster pushes live events over ActionCable so the dashboard
# updates the moment something happens instead of waiting for its next poll.
# It is the ONLY place that decides what gets broadcast and where:
#
#   job_started / job_finished  -> "jobs", "job_<id>", "test_run_<id>"
#   run_progress                -> "test_run_<id>"
#   worker_heartbeat / worker_offline / worker_online -> "workers"
#
# Payloads mirror the REST API serialization so the frontend can reuse its
# types. Every broadcast is fire-and-forget and failure-tolerant: a down or
# absent ActionCable server must never break job execution.
class RealtimeBroadcaster
  class << self
    def job_started(job)
      job_event("job_started", job)
    end

    def job_finished(job)
      job_event("job_finished", job)
    end

    def run_progress(test_run)
      safe_broadcast("test_run_#{test_run.id}", { type: "run_progress", test_run: test_run.progress_snapshot })
    end

    def worker_heartbeat(worker)
      worker_event("worker_heartbeat", worker)
    end

    def worker_online(worker)
      worker_event("worker_online", worker)
    end

    def worker_offline(worker)
      worker_event("worker_offline", worker)
    end

    private

    def job_event(kind, job)
      payload = {
        type: kind,
        job: {
          id: job.id,
          test_run_id: job.test_run_id,
          worker_id: job.worker_id,
          chunk_number: job.chunk_number,
          test_count: job.test_count,
          status: job.status,
          started_at: job.started_at,
          finished_at: job.finished_at,
          retry_count: job.retry_count
        }
      }
      safe_broadcast("jobs", payload)
      safe_broadcast("job_#{job.id}", payload)
      safe_broadcast("test_run_#{job.test_run_id}", payload)
    end

    def worker_event(kind, worker)
      safe_broadcast("workers", {
        type: kind,
        worker: {
          id: worker.id,
          worker_name: worker.worker_name,
          status: worker.status,
          last_seen_at: worker.last_seen_at,
          cpu_usage: worker.cpu_usage,
          memory_usage: worker.memory_usage,
          execution_count: worker.execution_count,
          current_job_id: worker.current_job_id
        }
      })
    end

    def safe_broadcast(stream, payload)
      ActionCable.server.broadcast(stream, payload)
    rescue StandardError => e
      Rails.logger.warn("[RealtimeBroadcaster] Broadcast to #{stream} failed: #{e.message}")
    end
  end
end
