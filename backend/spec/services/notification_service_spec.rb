require "rails_helper"

RSpec.describe NotificationService do
  let(:project) { create(:project) }

  describe ".notify" do
    it "creates and broadcasts a notification" do
      expect(DashboardEventService).to receive(:notification_created).with(an_instance_of(Notification))

      record = described_class.notify(project: project, title: "Gate approved", category: :deployment_gate)

      expect(record).to be_persisted
      expect(record.title).to eq("Gate approved")
      expect(record.category).to eq("deployment_gate")
      expect(record.project).to eq(project)
    end
  end

  describe ".mark_read" do
    it "marks a single notification as read" do
      record = create(:notification, read: false)
      described_class.mark_read(record)
      expect(record.reload.read?).to be(true)
    end
  end

  describe ".mark_all_read_for" do
    it "marks every unread notification in the scope as read" do
      ours = create_list(:notification, 2, project: project)
      other = create(:notification, project: create(:project))

      described_class.mark_all_read_for(Notification.where(project: project))

      expect(ours.map { |n| n.reload.read? }).to all(be(true))
      expect(other.reload.read?).to be(false)
    end
  end
end