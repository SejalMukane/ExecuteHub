# CiApiToken is a project-level API token Jenkins (or another CI system) uses
# to authenticate against ExecuteHub. Only the SHA-256 digest is persisted —
# the raw token is returned to the user exactly once, at creation/rotation,
# and can never be read back from the database.
class CiApiToken < ApplicationRecord
  belongs_to :project

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :token_prefix, presence: true

  scope :active, -> { where(revoked_at: nil) }
  scope :for_project, ->(project) { where(project: project) }

  def revoked?
    revoked_at.present?
  end

  def active?
    revoked_at.blank?
  end

  def touch_used!
    update_column(:last_used_at, Time.current)
  end
end