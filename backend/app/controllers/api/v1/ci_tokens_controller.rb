module Api
  module V1
    # User-facing management of project-level CI API tokens. Only admins and
    # developers can create/rotate/revoke; everyone with access to the project
    # can list token metadata (never the raw token, never the digest).
    class CiTokensController < ApplicationController
      include Authenticatable

      before_action :set_project, only: [:create]
      before_action :authorize_write, only: [:create]
      before_action :set_token, only: [:destroy, :rotate]

      # GET /api/v1/ci_tokens?project_id= — list token metadata for a project
      # (or across all visible projects when no project is given).
      def index
        records = if params[:project_id].present?
                    token_scope.where(project_id: params[:project_id])
                  else
                    token_scope
                  end
        render json: { ci_tokens: records.order(created_at: :desc).map { |t| token_response(t) } }
      end

      # POST /api/v1/ci_tokens { project_id, name } — create a token and
      # return the plaintext exactly once.
      def create
        record, plaintext = CiApiTokenService.create!(project: @project, name: params[:name].presence || "CI Token")
        render json: { ci_token: token_response(record), token: plaintext }, status: :created
      end

      # DELETE /api/v1/ci_tokens/:id — revoke a token immediately.
      def destroy
        CiApiTokenService.revoke!(@ci_token)
        head :no_content
      end

      # POST /api/v1/ci_tokens/:id/rotate — revoke the current token and issue
      # a fresh one. The new plaintext is returned exactly once.
      def rotate
        record, plaintext = CiApiTokenService.rotate!(@ci_token)
        render json: { ci_token: token_response(record), token: plaintext }
      end

      private

      def set_project
        @project = visible_projects.find_by(id: params[:project_id])
        render json: { error: "Project not found" }, status: :not_found unless @project
      end

      def set_token
        @ci_token = token_scope.find_by(id: params[:id])
        render json: { error: "Token not found" }, status: :not_found unless @ci_token
      end

      def token_scope
        CiApiToken.where(project: visible_projects)
      end

      def visible_projects
        if current_user.admin?
          Project.all
        else
          Project.where(user: current_user).or(Project.where(team: current_user.team))
        end
      end

      def authorize_write
        return if current_user.admin? || current_user.developer?

        render json: { error: "You do not have permission to manage CI tokens" }, status: :forbidden
      end

      def token_response(token)
        {
          id: token.id,
          project_id: token.project_id,
          name: token.name,
          token_prefix: token.token_prefix,
          last_used_at: token.last_used_at,
          revoked_at: token.revoked_at,
          created_at: token.created_at
        }
      end
    end
  end
end