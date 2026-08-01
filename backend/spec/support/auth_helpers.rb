require "rails_helper"

# Helpers for request specs that need an authenticated Bearer token.
module AuthHelpers
  def auth_headers_for(user)
    token = JwtService.encode(user_id: user.id)
    { "Authorization" => "Bearer #{token}" }
  end
end
