module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user
  end

  private

  def authenticate_user
    header = request.headers["Authorization"]
    token = header&.split(" ")&.last
    decoded = JwtService.decode(token)
    @current_user = User.find_by(id: decoded&.dig(:user_id))
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  def current_user
    @current_user
  end
end
