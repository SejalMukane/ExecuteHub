module Api
  module V1
    # User-facing Pipeline API: a list of CI/CD runs with their current status,
    # and a detail view with the builds, test runs and deployment gate that make
    # up a pipeline. Read-only — pipelines are created by triggers/webhooks and
    # settled by callbacks/workers.
    class PipelinesController < ApplicationController
      include Authenticatable

      # `status` is a light polling endpoint also used by the Jenkinsfile to
      # wait on the deployment gate. It accepts either a project CI token
      # (Bearer or X-ExecuteHub-Token) or a normal user JWT.
      skip_before_action :authenticate_user, only: [:status]
      before_action :authenticate_status_request, only: [:status]
      before_action :set_pipeline, only: [:show, :status]

      # GET /api/v1/pipelines?project_id=&status=
      def index
        scope = visible_pipelines
        scope = scope.where(project_id: params[:project_id]) if params[:project_id].present?
        scope = scope.where(status: params[:status]) if params[:status].present?
        render json: {
          pipelines: scope.recent.limit(100).map { |p| pipeline_list_response(p) }
        }
      end

      # GET /api/v1/pipelines/:id — detail with builds, test runs and gate.
      def show
        render json: {
          pipeline: pipeline_detail_response(@pipeline),
          builds: @pipeline.builds.recent.map { |b| build_response(b) },
          test_runs: @pipeline.test_runs.recent.map { |r| test_run_response(r) },
          deployment_gate: @pipeline.deployment_gate ? gate_response(@pipeline.deployment_gate) : nil
        }
      end

      # GET /api/v1/pipelines/:id/status — light polling snapshot.
      def status
        run = @pipeline.test_runs.recent.first
        render json: {
          pipeline: pipeline_list_response(@pipeline),
          test_run_progress: run ? run.progress_snapshot : nil,
          deployment_gate: @pipeline.deployment_gate ? gate_response(@pipeline.deployment_gate) : nil
        }
      end

      private

      def set_pipeline
        @pipeline = pipeline_scope.find_by(id: params[:id])
        render json: { error: "Pipeline not found" }, status: :not_found unless @pipeline
      end

      # Jenkins polls the gate through the `status` endpoint with its project
      # CI token; when present, scope visibility to that project. Otherwise
      # fall back to normal user authentication + project visibility.
      def authenticate_status_request
        token = request.headers["Authorization"]&.split(" ")&.last
        token ||= request.headers["X-ExecuteHub-Token"]
        if token.present? && (ci_token = CiApiTokenService.authenticate(token))
          @status_pipeline_scope = ci_token.project.pipelines
          return
        end

        authenticate_user
      end

      def pipeline_scope
        @status_pipeline_scope || Pipeline.where(project: visible_projects)
      end

      def visible_pipelines
        Pipeline.where(project: visible_projects)
      end

      def visible_projects
        if current_user.admin?
          Project.all
        else
          Project.where(user: current_user).or(Project.where(team: current_user.team))
        end
      end

      def pipeline_list_response(pipeline)
        latest_gate = pipeline.deployment_gate
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
          ci_key: pipeline.ci_key,
          build_count: pipeline.builds.count,
          test_run_count: pipeline.test_runs.count,
          gate_status: latest_gate&.status,
          created_at: pipeline.created_at,
          finished_at: pipeline.builds.maximum(:finished_at)
        }
      end

      def pipeline_detail_response(pipeline)
        pipeline_list_response(pipeline).merge(updated_at: pipeline.updated_at)
      end

      def build_response(build)
        {
          id: build.id,
          test_run_id: build.test_run_id,
          jenkins_job_name: build.jenkins_job_name,
          jenkins_build_number: build.jenkins_build_number,
          status: build.status,
          branch: build.branch,
          commit_sha: build.commit_sha,
          started_at: build.started_at,
          finished_at: build.finished_at,
          duration: build.duration,
          duration_seconds: build.duration_seconds,
          url: JenkinsService.build_url(build.jenkins_build_number)
        }
      end

      def test_run_response(test_run)
        {
          id: test_run.id,
          status: test_run.status,
          total_tests: test_run.total_tests,
          passed_tests: test_run.passed_tests,
          failed_tests: test_run.failed_tests,
          progress_percentage: test_run.progress_percentage,
          started_at: test_run.started_at,
          finished_at: test_run.finished_at
        }
      end

      def gate_response(gate)
        {
          id: gate.id,
          pipeline_id: gate.pipeline_id,
          test_run_id: gate.test_run_id,
          status: gate.status,
          reason: gate.reason,
          requires_approval: gate.requires_approval,
          decided_at: gate.decided_at,
          created_at: gate.created_at
        }
      end
    end
  end
end
