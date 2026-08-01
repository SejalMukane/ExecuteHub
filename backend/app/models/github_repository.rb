class GithubRepository < ApplicationRecord
  belongs_to :project
  belongs_to :github_integration

  has_one :github_webhook, dependent: :destroy

  validates :full_name, presence: true, uniqueness: true
  validates :github_repo_id, presence: true, uniqueness: true
end
