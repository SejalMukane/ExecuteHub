require "rails_helper"

RSpec.describe TestRun, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:jobs).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:branch) }
    it { is_expected.to validate_presence_of(:commit_sha) }
    it { is_expected.to validate_presence_of(:total_tests) }

    it "rejects a non-positive total_tests" do
      test_run = build(:test_run, total_tests: 0)
      expect(test_run).not_to be_valid
    end

    it "rejects a negative progress_percentage" do
      test_run = build(:test_run, progress_percentage: -1)
      expect(test_run).not_to be_valid
    end

    it "rejects a progress_percentage above 100" do
      test_run = build(:test_run, progress_percentage: 101)
      expect(test_run).not_to be_valid
    end
  end

  describe "status enum" do
    it "defaults to queued" do
      expect(described_class.new.status).to eq("queued")
    end

    it "exposes the documented statuses" do
      expect(described_class.statuses.keys).to match_array(
        %w[queued scheduling running completed failed cancelled]
      )
    end

    it "provides predicate helpers" do
      test_run = build(:test_run, status: :running)
      expect(test_run.running?).to be(true)
      expect(test_run.completed?).to be(false)
    end
  end

  describe "scopes" do
    it "orders by newest first" do
      older = create(:test_run, created_at: 2.days.ago)
      newer = create(:test_run, created_at: 1.day.ago)
      expect(described_class.recent.to_a).to eq([newer, older])
    end
  end
end
