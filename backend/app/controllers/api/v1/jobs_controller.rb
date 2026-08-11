module Api
  module V1
    # Jobs API — read-only execution detail for a single Job:
    #
    #   GET /jobs/:id        status, duration, logs, artifacts, execution summary
    #   GET /jobs/:id/logs   live execution logs (oldest first)
    #   GET /jobs/:id/artifacts  screenshots / videos / trace metadata
    class JobsController < ApplicationController
      include Authenticatable

      before_action :set_job

      # GET /api/v1/jobs/:id
      def show
        render json: { job: job_response(@job, include: true) }
      end

      # GET /api/v1/jobs/:id/logs
      def logs
        render json: { logs: @job.execution_logs.chronological.map { |log| log_response(log) } }
      end

      # GET /api/v1/jobs/:id/artifacts
      def artifacts
        render json: { artifacts: @job.artifacts.order(:artifact_type, :id).map { |artifact| artifact_response(artifact) } }
      end

      private

      def set_job
        @job = visible_jobs.find_by(id: params[:id])
        render json: { error: "Job not found" }, status: :not_found unless @job
      end

      def visible_jobs
        Job.where(test_run: TestRun.where(project: visible_projects))
      end

      def visible_projects
        if current_user.admin?
          Project.all
        else
          Project.where(user: current_user).or(Project.where(team: current_user.team))
        end
      end

      def job_response(job, include: false)
        response = {
          id: job.id,
          test_run_id: job.test_run_id,
          worker_id: job.worker_id,
          container_id: job.container_id,
          chunk_number: job.chunk_number,
          test_count: job.test_count,
          status: job.status,
          passed_tests: job.passed_tests,
          failed_tests: job.failed_tests,
          duration_ms: job.duration_ms,
          duration_seconds: job.duration_seconds,
          error_message: job.error_message,
          retry_count: job.retry_count,
          started_at: job.started_at,
          finished_at: job.finished_at
        }
        if include
          response[:logs] = job.execution_logs.chronological.map { |log| log_response(log) }
          response[:artifacts] = job.artifacts.order(:artifact_type, :id).map { |artifact| artifact_response(artifact) }
          response[:summary] = summary_response(job)
        end
        response
      end

      def log_response(log)
        {
          id: log.id,
          timestamp: log.timestamp,
          level: log.level,
          message: log.message
        }
      end

      def artifact_response(artifact)
        {
          id: artifact.id,
          job_id: artifact.job_id,
          test_run_id: artifact.test_run_id,
          artifact_type: artifact.artifact_type,
          file_name: artifact.file_name,
          s3_key: artifact.s3_key,
          content_type: artifact.content_type || content_type_for(artifact.artifact_type),
          file_size: artifact.size,
          checksum: artifact.checksum,
          status: artifact.status,
          storage_backend: StorageService.storage_backend,
          created_at: artifact.created_at
        }
      end

      def content_type_for(type)
        case type
        when "screenshot" then "image/png"
        when "video" then "video/webm"
        when "trace" then "application/zip"
        when "log" then "text/plain"
        when "report" then "application/json"
        else "application/octet-stream"
        end
      end

      def summary_response(job)
        {
          passed: job.passed_tests,
          failed: job.failed_tests,
          duration_ms: job.duration_ms,
          exit_status: job.status
        }
      end
    end
  end
end
