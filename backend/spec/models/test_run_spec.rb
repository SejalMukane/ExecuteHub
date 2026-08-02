require "rails_helper"

RSpec.describe TestRun, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:test_suite).optional }
    it { is_expected.to have_many(:jobs).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:branch) }
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

  describe "#progress_snapshot" do
    it "returns the live counters for the distributed dashboard" do
      test_run = create(:test_run, total_tests: 40, total_jobs: 2, queued_jobs: 0,
                                   running_jobs: 1, completed_jobs: 1, failed_jobs: 0,
                                   passed_tests: 20, failed_tests: 0,
                                   total_screenshots: 3, total_videos: 1,
                                   total_duration_ms: 1234, progress_percentage: 50.0,
                                   started_at: Time.current)

      snapshot = test_run.progress_snapshot

      expect(snapshot[:id]).to eq(test_run.id)
      expect(snapshot[:status]).to eq("queued")
      expect(snapshot[:total_jobs]).to eq(2)
      expect(snapshot[:queued_jobs]).to eq(0)
      expect(snapshot[:running_jobs]).to eq(1)
      expect(snapshot[:completed_jobs]).to eq(1)
      expect(snapshot[:failed_jobs]).to eq(0)
      expect(snapshot[:passed_tests]).to eq(20)
      expect(snapshot[:failed_tests]).to eq(0)
      expect(snapshot[:total_duration_ms]).to eq(1234)
      expect(snapshot[:progress_percentage]).to eq(50.0)
      expect(snapshot[:started_at]).to be_present
    end
  end
end
