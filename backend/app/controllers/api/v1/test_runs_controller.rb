module Api
  module V1
    class TestRunsController < ApplicationController
      include Authenticatable

      before_action :set_project, only: [:create]
      before_action :set_test_run, only: [:show]
      before_action :authorize_write, only: [:create]

      # GET /api/v1/test_runs — newest first.
      def index
        test_runs = visible_test_runs.order(created_at: :desc)
        render json: { test_runs: test_runs.map { |run| test_run_response(run) } }
      end

      # GET /api/v1/test_runs/:id — includes the run's jobs and progress.
      def show
        render json: { test_run: test_run_response(@test_run, include_jobs: true) }
      end

      # POST /api/v1/projects/:project_id/test_runs
      # Creates a TestRun, fans it out into Job chunks via the scheduler, then
      # returns the fully scheduled run. The controller stays thin — scheduling
      # logic lives in TestScheduler.
      def create
        test_run = @project.test_runs.new(test_run_params)

        if test_run.save
          Rails.logger.info("[TestRunsController] Created TestRun ##{test_run.id} for Project ##{@project.id}")
          TestScheduler.call(test_run)
          render json: { test_run: test_run_response(test_run.reload, include_jobs: true) }, status: :created
        else
          render json: { errors: test_run.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_project
        @project = visible_projects.find_by(id: params[:project_id])
        render json: { error: "Project not found" }, status: :not_found unless @project
      end

      def set_test_run
        @test_run = visible_test_runs.find_by(id: params[:id])
        render json: { error: "Test run not found" }, status: :not_found unless @test_run
      end

      def visible_projects
        if current_user.admin?
          Project.all
        else
          Project.where(user: current_user).or(Project.where(team: current_user.team))
        end
      end

      def visible_test_runs
        TestRun.where(project: visible_projects)
      end

      def authorize_write
        return if current_user.admin? || current_user.developer?
        render json: { error: "You do not have permission to create test runs" }, status: :forbidden
      end

      def test_run_params
        params.permit(:branch, :commit_sha, :total_tests)
      end

      def test_run_response(test_run, include_jobs: false)
        {
          id: test_run.id,
          project_id: test_run.project_id,
          project_name: test_run.project.name,
          branch: test_run.branch,
          commit_sha: test_run.commit_sha,
          status: test_run.status,
          total_tests: test_run.total_tests,
          total_jobs: test_run.total_jobs,
          completed_jobs: test_run.completed_jobs,
          failed_jobs: test_run.failed_jobs,
          queued_jobs: test_run.queued_jobs,
          progress_percentage: test_run.progress_percentage,
          started_at: test_run.started_at,
          finished_at: test_run.finished_at,
          created_at: test_run.created_at,
          jobs: include_jobs ? test_run.jobs.order(:chunk_number).map { |job| job_response(job) } : nil
        }
      end

      def job_response(job)
        {
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
      end
    end
  end
end
