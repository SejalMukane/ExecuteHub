module Api
  module V1
    class GithubRepositoriesController < ApplicationController
      include Authenticatable

      before_action :require_integration, only: [:index, :connect]
      before_action :authorize_write, only: [:connect, :disconnect]

      def index
        repos = GithubService.repos(integration.access_token)
        render json: { repositories: repos.map { |r| repo_summary(r) } }
      rescue GithubService::Error => e
        render json: { error: e.message }, status: e.status
      end

      def connect
        project = visible_projects.find_by(id: params[:project_id])
        return render json: { error: "Project not found" }, status: :not_found unless project

        full_name = params[:full_name]
        data = GithubService.repo(integration.access_token, full_name)

        repo = GithubRepository.find_or_initialize_by(project: project)
        repo.update!(
          github_integration: integration,
          github_repo_id: data["id"],
          full_name: data["full_name"],
          html_url: data["html_url"],
          clone_url: data["clone_url"],
          ssh_url: data["ssh_url"],
          default_branch: data["default_branch"],
          description: data["description"],
          private: data["private"] || false
        )

        webhook = repo.github_webhook || repo.build_github_webhook
        webhook.slug ||= SecureRandom.hex(16)
        webhook.secret ||= SecureRandom.hex(32)
        webhook_url = webhook_base + "/" + webhook.slug
        meta = GithubService.create_webhook(
          integration.access_token,
          full_name,
          webhook_url,
          secret: webhook.secret
        )
        webhook.update!(
          github_webhook_id: meta["id"],
          url: webhook_url,
          events: meta["events"]&.join(","),
          active: meta["active"],
          slug: webhook.slug,
          secret: webhook.secret
        )

        render json: { github_repository: repository_response(repo, webhook) }, status: :created
      rescue GithubService::Error => e
        render json: { error: e.message }, status: e.status
      end

      def disconnect
        project = visible_projects.find_by(id: params[:project_id])
        return render json: { error: "Project not found" }, status: :not_found unless project

        repo = project.github_repository
        return head :no_content unless repo

        repo.github_webhook&.delete_on_github
        repo.destroy
        head :no_content
      rescue GithubService::Error => e
        render json: { error: e.message }, status: e.status
      end

      def show
        project = visible_projects.find_by(id: params[:project_id])
        return render json: { error: "Project not found" }, status: :not_found unless project

        repo = project.github_repository
        return render json: { github_repository: nil, deliveries: [] } unless repo

        webhook = repo.github_webhook
        deliveries = webhook ? webhook.github_webhook_deliveries.order(received_at: :desc).limit(20) : []
        render json: {
          github_repository: repository_response(repo, webhook),
          deliveries: deliveries.map { |d| delivery_response(d) }
        }
      end

      private

      def integration
        @integration ||= current_user.github_integration
      end

      def require_integration
        render json: { error: "Connect your GitHub account first" }, status: :unprocessable_entity unless integration
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
        render json: { error: "You do not have permission to modify projects" }, status: :forbidden
      end

      def webhook_base
        ENV.fetch("GITHUB_WEBHOOK_URL", "http://localhost:3001/api/v1/github/webhooks").sub(%r{/+\z}, "")
      end

      def repo_summary(repo)
        {
          id: repo["id"],
          full_name: repo["full_name"],
          html_url: repo["html_url"],
          private: repo["private"],
          description: repo["description"],
          default_branch: repo["default_branch"]
        }
      end

      def repository_response(repo, webhook)
        {
          id: repo.id,
          full_name: repo.full_name,
          html_url: repo.html_url,
          clone_url: repo.clone_url,
          ssh_url: repo.ssh_url,
          default_branch: repo.default_branch,
          private: repo.private,
          description: repo.description,
          created_at: repo.created_at,
          webhook: webhook ? webhook_response(webhook) : nil
        }
      end

      def webhook_response(webhook)
        {
          id: webhook.id,
          github_webhook_id: webhook.github_webhook_id,
          url: webhook.url,
          events: webhook.events_list,
          active: webhook.active,
          last_delivery_at: webhook.last_delivery_at
        }
      end

      def delivery_response(delivery)
        {
          id: delivery.id,
          delivery_id: delivery.delivery_id,
          event: delivery.event,
          signature_valid: delivery.signature_valid,
          received_at: delivery.received_at,
          payload: delivery.payload
        }
      end
    end
  end
end
