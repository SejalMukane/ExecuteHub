module Api
  module V1
    # User-facing Build API: the Jenkins builds belonging to visible projects.
    # Read-only.
    class BuildsController < ApplicationController
      include Authenticatable

      before_action :set_build, only: [:show]

      # GET /api/v1/builds?project_id=&pipeline_id=&status=
      def index
        scope = visible_builds
        scope = scope.where(project_id: params[:project_id]) if params[:project_id].present?
        scope = scope.where(pipeline_id: params[:pipeline_id]) if params[:pipeline_id].present?
        scope = scope.where(status: params[:status]) if params[:status].present?
        render json: { builds: scope.recent.limit(100).map { |b| build_response(b) } }
      end

      # GET /api/v1/builds/:id
      def show
        render json: { build: build_response(@build) }
      end

      private

      def set_build
        @build = visible_builds.find_by(id: params[:id])
        render json: { error: "Build not found" }, status: :not_found unless @build
      end

      def visible_builds
        Build.where(project: visible_projects)
      end

      def visible_projects
        if current_user.admin?
          Project.all
        else
          Project.where(user: current_user).or(Project.where(team: current_user.team))
        end
      end

      def build_response(build)
        {
          id: build.id,
          project_id: build.project_id,
          pipeline_id: build.pipeline_id,
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
    end
  end
end
