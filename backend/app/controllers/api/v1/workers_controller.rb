module Api
  module V1
    # Worker Pool endpoints: who is registered, what they are doing, and how
    # the pool is split between idle / busy / offline. Reads only WorkerHeartbeat
    # state — nothing is mutated here.
    class WorkersController < ApplicationController
      include Authenticatable

      # GET /api/v1/workers — pool summary + every worker.
      def index
        workers = WorkerHeartbeat.order(:worker_name)
        render json: {
          counts: WorkerRegistry.counts,
          workers: workers.map { |worker| worker_response(worker) }
        }
      end

      # GET /api/v1/workers/:id — one worker with its current job (if busy).
      def show
        worker = WorkerHeartbeat.find_by(id: params[:id])
        return render json: { error: "Worker not found" }, status: :not_found unless worker

        render json: { worker: worker_response(worker) }
      end

      private

      def worker_response(worker)
        job = worker.current_job
        {
          id: worker.id,
          worker_name: worker.worker_name,
          status: worker.status,
          last_seen_at: worker.last_seen_at,
          cpu_usage: worker.cpu_usage,
          memory_usage: worker.memory_usage,
          execution_count: worker.execution_count,
          current_job: job && {
            id: job.id,
            test_run_id: job.test_run_id,
            chunk_number: job.chunk_number,
            test_count: job.test_count,
            status: job.status,
            started_at: job.started_at
          }
        }
      end
    end
  end
end
