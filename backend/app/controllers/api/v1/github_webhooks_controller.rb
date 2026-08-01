module Api
  module V1
    class GithubWebhooksController < ApplicationController
      def receive
        webhook = GithubWebhook.find_by(slug: params[:slug])
        return head :not_found unless webhook

        body = request.raw_post
        signature = request.headers["X-Hub-Signature-256"]
        valid = GithubWebhookSignature.valid?(webhook.secret, body, signature)

        payload = parse_json(body)
        event = request.headers["X-GitHub-Event"]

        if payload["repository"].present?
          return head :forbidden unless payload["repository"]["full_name"] == webhook.github_repository.full_name
        end

        webhook.github_webhook_deliveries.create!(
          delivery_id: request.headers["X-GitHub-Delivery"],
          event: event,
          payload: payload,
          signature_valid: valid,
          received_at: Time.current
        )
        webhook.update!(last_delivery_at: Time.current)

        return head :unauthorized unless valid

        head :ok
      end

      private

      def parse_json(body)
        JSON.parse(body)
      rescue JSON::ParserError
        {}
      end
    end
  end
end
