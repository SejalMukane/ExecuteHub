class GithubWebhook < ApplicationRecord
  belongs_to :github_repository

  has_many :github_webhook_deliveries, dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :secret, presence: true

  def events_list
    events.to_s.split(",").map(&:strip).reject(&:empty?)
  end

  def delete_on_github
    return unless github_webhook_id.present?
    integration = github_repository.github_integration
    return unless integration

    GithubService.delete_webhook(integration.access_token, github_repository.full_name, github_webhook_id)
  end
end
