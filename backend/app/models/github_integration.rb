class GithubIntegration < ApplicationRecord
  belongs_to :user

  has_many :github_repositories, dependent: :destroy
  has_many :github_webhooks, through: :github_repositories

  validates :github_login, presence: true
  validates :access_token, presence: true
end
