# CiAuthenticatable authenticates CI-to-ExecuteHub requests (Jenkins triggers,
# callbacks, status polls) using a project-level CI API token. The token is
# read from `Authorization: Bearer <token>` or `X-ExecuteHub-Token`.
#
# On success it exposes:
#   @ci_token   the CiApiToken record (already last_used'ed)
#   @ci_project the Project owning the token
#
# The token is looked up by its SHA-256 digest — the raw token never touches
# the database or the logs. Controllers that use this concern must also
# validate that the payload's project_id matches @ci_project (otherwise a
# project's token could be used against another project).
module CiAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_ci_request
  end

  private

  def authenticate_ci_request
    token = bearer_token || custom_token_header
    @ci_token = CiApiTokenService.authenticate(token)
    @ci_project = @ci_token&.project
    render json: { error: "Unauthorized" }, status: :unauthorized unless @ci_project
  end

  def bearer_token
    request.headers["Authorization"]&.split(" ")&.last
  end

  def custom_token_header
    request.headers["X-ExecuteHub-Token"]
  end

  # CI token scoping: the request must belong to the token's own project.
  # project_id in the payload is only ever trusted AFTER this check.
  def authorize_ci_project!(scoped_project)
    return if @ci_project == scoped_project

    render json: { error: "Token does not belong to this project" }, status: :forbidden
  end
end