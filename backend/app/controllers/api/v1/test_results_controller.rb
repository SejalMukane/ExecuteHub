module Api
  module V1
    # TestResultsController exposes a single test's outcome and, for failures,
    # the full debugging evidence (Part 10/16): error message, stack trace,
    # browser, worker, duration, retries and the Job's artifacts + logs.
    #
    #   GET /test_results/:id
    class TestResultsController < ApplicationController
      include Authenticatable

      before_action :set_test_result

      def show
        render json: { test_result: test_result_response(@test_result, include_detail: true) }
      end

      private

      def set_test_result
        @test_result = visible_test_results.find_by(id: params[:id])
        render json: { error: "Test result not found" }, status: :not_found unless @test_result
      end

      def visible_test_results
        TestResult.where(test_run: TestRun.where(project: visible_projects))
      end

      def visible_projects
        if current_user.admin?
          Project.all
        else
          Project.where(user: current_user).or(Project.where(team: current_user.team))
        end
      end

      def test_result_response(result, include_detail: false)
        response = {
          id: result.id,
          job_id: result.job_id,
          test_run_id: result.test_run_id,
          test_name: result.test_name,
          suite_name: result.suite_name,
          status: result.status,
          duration_ms: result.duration_ms,
          browser: result.browser,
          error_message: result.error_message,
          retry_count: result.retry_count,
          started_at: result.started_at,
          finished_at: result.finished_at,
          worker: result.job.worker_id
        }
        if include_detail
          response[:stack_trace] = result.stack_trace
          response[:job] = job_response(result.job)
          response[:artifacts] = result.job.artifacts.order(:artifact_type, :id)
                                   .map { |artifact| artifact_response(artifact) }
          response[:logs] = result.job.execution_logs.chronological.map { |log| log_response(log) }
        end
        response
      end

      def job_response(job)
        {
          id: job.id,
          test_run_id: job.test_run_id,
          worker_id: job.worker_id,
          chunk_number: job.chunk_number,
          status: job.status,
          retry_count: job.retry_count,
          started_at: job.started_at,
          finished_at: job.finished_at
        }
      end

      def artifact_response(artifact)
        {
          id: artifact.id,
          job_id: artifact.job_id,
          artifact_type: artifact.artifact_type,
          file_name: artifact.file_name,
          file_size: artifact.size,
          status: artifact.status
        }
      end

      def log_response(log)
        {
          id: log.id,
          timestamp: log.timestamp,
          level: log.level,
          message: log.message
        }
      end
    end
  end
end
