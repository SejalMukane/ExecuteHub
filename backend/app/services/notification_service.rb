# NotificationService is the only way to create/acknowledge in-app
# notifications. Creating one persists the record AND broadcasts it to the
# project's notifications stream and the dashboard via Action Cable, so the
# UI updates without a refresh.
class NotificationService
  def self.notify(project: nil, title:, description: nil, category: :system,
                  test_run: nil, pipeline: nil)
    record = Notification.create!(
      project: project,
      title: title,
      description: description,
      category: category,
      test_run: test_run,
      pipeline: pipeline
    )
    DashboardEventService.notification_created(record)
    record
  end

  def self.mark_read(notification)
    notification.mark_read!
  end

  def self.mark_all_read(project)
    mark_all_read_for(Notification.where(project: project))
  end

  def self.mark_all_read_for(scope)
    scope.where(read: false).update_all(read: true)
  end
end