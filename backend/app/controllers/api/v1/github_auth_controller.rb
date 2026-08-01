module Api
  module V1
    class GithubAuthController < ApplicationController
      include Authenticatable

      skip_before_action :authenticate_user, only: [:callback]

      def start
        state = JwtService.encode(user_id: current_user.id, purpose: "github_oauth")
        url = GithubService.authorize_url(state: state)
        render json: { url: url }
      rescue GithubService::Error => e
        render json: { error: e.message }, status: e.status
      end

      def callback
        code = params[:code]
        decoded = JwtService.decode(params[:state])
        user = decoded&.dig(:user_id) && decoded[:purpose] == "github_oauth" ? User.find_by(id: decoded[:user_id]) : nil

        if code.blank? || user.nil?
          return redirect_to callback_redirect("github=error"), allow_other_host: true
        end

        token_data = GithubService.exchange_code(code)
        access_token = token_data["access_token"]
        if access_token.blank?
          return redirect_to callback_redirect("github=error"), allow_other_host: true
        end

        github_user = GithubService.user(access_token)
        integration = GithubIntegration.find_or_initialize_by(user: user)
        integration.update!(
          github_user_id: github_user["id"],
          github_login: github_user["login"],
          access_token: access_token,
          scope: token_data["scope"]
        )

        redirect_to callback_redirect("github=connected"), allow_other_host: true
      rescue GithubService::Error
        redirect_to callback_redirect("github=error"), allow_other_host: true
      end

      def status
        integration = current_user.github_integration
        render json: {
          connected: integration.present?,
          login: integration&.github_login
        }
      end

      def disconnect
        integration = current_user.github_integration
        if integration
          integration.github_webhooks.each do |webhook|
            begin
              webhook.delete_on_github
            rescue GithubService::Error
              # Best-effort cleanup: local removal proceeds even if GitHub is unreachable.
            end
          end
          integration.destroy
        end
        head :no_content
      end

      private

      def callback_redirect(query)
        base = ENV.fetch("FRONTEND_URL", "http://localhost:3000")
        "#{base}/projects?#{query}"
      end
    end
  end
end
