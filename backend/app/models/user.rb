class User < ApplicationRecord
  has_secure_password

  ROLES = %w[admin developer qa].freeze

  belongs_to :team, optional: true

  has_many :browser_sessions, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_one :github_integration, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }

  def admin?
    role == "admin"
  end

  def developer?
    role == "developer"
  end

  def qa?
    role == "qa"
  end
end
