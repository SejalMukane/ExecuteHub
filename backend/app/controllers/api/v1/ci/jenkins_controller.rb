module Api
  module V1
    module Ci
      # POST /api/v1/ci/jenkins/test_runs
      #
      # Called by a Jenkinsfile right after a build starts to register the run
      # in ExecuteHub. Authenticated with a project CI token
      # (Authorization: Bearer <token> or X-ExecuteHub-Token).
      #
      # Idempotent: retrying the same Jenkins build (same job + build number)
      # returns the already-created Pipeline/Build/TestRun instead of
      # duplicating records or double-scheduling jobs.
      class JenkinsController < ApplicationController
        include CiAuthenticatable

        before_action :set_project
        before_action :authorize_project_scope, only: [:create_test_run]

        skip_before_action :authenticate_ci_request, only: [:callback]
        before_action :authenticate_callback_secret, only: [:callback]
        before_action :set_build_by_identity, only: [:callback]

        def create_test_run
          result = CiTriggerService.call(
            project: @project,
            branch: params[:branch],
            commit_sha: params[:commit_sha],
            jenkins_build_number: params[:jenkins_build_number],
            job_name: params[:job_name],
            total_tests: params[:total_tests],
            test_suite_id: params[:test_suite_id]
          )

          Rails.logger.info("[Ci::JenkinsController] TestRun ##{result.test_run.id} " \
                            "for #{result.pipeline.ci_key} (created=#{result.created})")

          render json: {
            pipeline: pipeline_response(result.pipeline),
            build: build_response(result.build),
            test_run: test_run_response(result.test_run)
          }, status: result.created ? :created : :ok
        rescue CiTriggerService::InvalidParameters => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        # POST /api/v1/ci/jenkins/callback
        #
        # Jenkins webhook: reports a build transition (started / succeeded /
        # failed / aborted). Authenticated by the shared secret in the
        # X-Jenkins-Callback-Secret header (constant-time comparison), then the
        # build identity is validated against an existing Build. Duplicate
        # webhooks are no-ops (JenkinsBuildCallbackService is idempotent).
        def callback
          result = JenkinsBuildCallbackService.call(
            build: @build,
            jenkins_status: params[:build_status] || params[:result]
          )

          render json: {
            build: build_response(result.build),
            pipeline: result.build.pipeline ? pipeline_response(result.build.pipeline) : nil,
            test_run: result.build.test_run ? test_run_response(result.build.test_run) : nil,
            applied: result.applied
          }
        end

        private

        def set_project
          @project = Project.find_by(id: params[:project_id])
          render json: { error: "Project not found" }, status: :not_found unless @project
        end

        def authorize_project_scope
          authorize_ci_project!(@project)
        end

        # Fail closed: when no secret is configured the endpoint is disabled,
        # and a provided secret must match exactly (constant-time compare).
        def authenticate_callback_secret
          configured = Rails.configuration.executehub[:jenkins]
                       .to_h.with_indifferent_access[:callback_shared_secret].to_s
          provided = request.headers["X-Jenkins-Callback-Secret"].to_s

          valid = configured.present? && ActiveSupport::SecurityUtils.secure_compare(configured, provided)
          render json: { error: "Unauthorized" }, status: :unauthorized unless valid
        end

        # The callback payload must reference a Build ExecuteHub already knows;
        # never trust a project_id that does not resolve to one.
        def set_build_by_identity
          @build = Build.find_by(
            project_id: params[:project_id],
            jenkins_job_name: params[:jenkins_job_name],
            jenkins_build_number: params[:jenkins_build_number]
          )
          render json: { error: "Build not found" }, status: :not_found unless @build
        end

        def pipeline_response(pipeline)
          {
            id: pipeline.id,
            project_id: pipeline.project_id,
            name: pipeline.name,
            provider: pipeline.provider,
            status: pipeline.status,
            branch: pipeline.branch,
            commit_sha: pipeline.commit_sha,
            triggered_by: pipeline.triggered_by,
            ci_key: pipeline.ci_key,
            created_at: pipeline.created_at
          }
        end

        def build_response(build)
          {
            id: build.id,
            pipeline_id: build.pipeline_id,
            test_run_id: build.test_run_id,
            jenkins_job_name: build.jenkins_job_name,
            jenkins_build_number: build.jenkins_build_number,
            status: build.status,
            started_at: build.started_at
          }
        end

        def test_run_response(test_run)
          {
            id: test_run.id,
            project_id: test_run.project_id,
            pipeline_id: test_run.pipeline_id,
            status: test_run.status,
            branch: test_run.branch,
            commit_sha: test_run.commit_sha,
            total_tests: test_run.total_tests,
            total_jobs: test_run.total_jobs,
            created_at: test_run.created_at
          }
        end
      end
    end
  end
end
