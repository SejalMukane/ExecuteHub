class TestSuite < ApplicationRecord
  has_many :test_runs

  validates :name, presence: true, uniqueness: true
  validates :total_tests, presence: true,
            numericality: { only_integer: true, greater_than: 0 }

  scope :recent, -> { order(created_at: :desc) }
end
