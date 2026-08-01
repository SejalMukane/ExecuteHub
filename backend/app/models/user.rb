class User < ApplicationRecord
  has_secure_password

  has_many :browser_sessions, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
end
