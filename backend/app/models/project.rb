class Project < ApplicationRecord
  belongs_to :user
  belongs_to :team

  validates :name, presence: true
end
