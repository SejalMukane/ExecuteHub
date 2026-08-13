require "rails_helper"

RSpec.describe Notification, type: :model do
  subject(:notification) { create(:notification) }

  it { is_expected.to belong_to(:project).optional }
  it { is_expected.to belong_to(:test_run).optional }
  it { is_expected.to belong_to(:pipeline).optional }
  it { is_expected.to validate_presence_of(:title) }

  describe "category enum" do
    it "defaults to system" do
      expect(described_class.new.category).to eq("system")
    end
  end

  describe ".unread" do
    it "only returns notifications that have not been read" do
      unread = create(:notification, read: false)
      read = create(:notification, read: true)
      expect(described_class.unread).to include(unread)
      expect(described_class.unread).not_to include(read)
    end
  end

  describe "#mark_read!" do
    it "flips the read flag" do
      notification.mark_read!
      expect(notification.reload.read?).to be(true)
    end
  end
end