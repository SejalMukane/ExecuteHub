class Team < ApplicationRecord
  has_many :users, dependent: :nullify
  has_many :projects, dependent: :destroy

  validates :name, presence: true
end
