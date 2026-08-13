# Notification is an in-app alert for a project — a finished TestRun, a
# pipeline outcome, a deployment gate that needs approval, or a system event.
# They are delivered to the frontend in real time via Action Cable
# (DashboardEventService.notification_created) and persisted so users can
# review them after the fact.
class Notification < ApplicationRecord
  belongs_to :project, optional: true
  belongs_to :test_run, optional: true
  belongs_to :pipeline, optional: true

  enum :category, {
    system: "system",
    test_run: "test_run",
    pipeline: "pipeline",
    deployment_gate: "deployment_gate"
  }, default: :system

  validates :title, presence: true
  validates :category, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :unread, -> { where(read: false) }
  scope :for_project, ->(project) { where(project: project) }

  def mark_read!
    update!(read: true)
  end
end