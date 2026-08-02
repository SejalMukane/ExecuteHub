module ApplicationCable
  # Authenticates WebSocket connections using the same Bearer JWT as the REST
  # API. The token is passed as a query parameter (`?token=...`) because
  # browsers cannot set Authorization headers on WebSocket upgrade requests.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      token = request.params[:token] || request.headers["Authorization"]&.split(" ")&.last
      decoded = JwtService.decode(token.to_s)
      user = User.find_by(id: decoded&.dig(:user_id))
      reject_unauthorized_connection unless user
      user
    end
  end
end
