class Project < ApplicationRecord
  belongs_to :user
  belongs_to :team

  has_one :github_repository, dependent: :destroy

  has_many :test_runs, dependent: :destroy

  validates :name, presence: true
end
