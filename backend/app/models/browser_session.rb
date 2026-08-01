class BrowserSession < ApplicationRecord
  belongs_to :user

  STATUSES = %w[pending running completed failed expired terminated].freeze

  validates :browser_name, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: %w[pending running]) }
  scope :completed, -> { where(status: "completed") }
  scope :for_user, ->(user) { where(user: user) }

  before_create :set_defaults

  def duration
    return nil unless start_time
    (end_time || Time.current) - start_time
  end

  def elapsed
    return 0 unless start_time
    ((end_time || Time.current) - start_time).to_i
  end

  private

  def set_defaults
    self.status ||= "running"
    self.start_time ||= Time.current
  end
end
