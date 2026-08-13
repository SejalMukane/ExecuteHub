require "rails_helper"

RSpec.describe Pipeline, type: :model do
  subject(:pipeline) { create(:pipeline) }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to have_many(:builds).dependent(:destroy) }
  it { is_expected.to have_many(:test_runs).dependent(:destroy) }
  it { is_expected.to have_one(:deployment_gate).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:ci_key) }
  it { is_expected.to validate_uniqueness_of(:ci_key) }

  describe "enums" do
    it "defines the expected providers" do
      expect(described_class.providers.keys).to match_array(%w[jenkins github_actions])
    end

    it "defines the expected statuses" do
      expect(described_class.statuses.keys).to match_array(%w[pending running passed failed cancelled blocked])
    end
  end

  describe "#terminal?" do
    it "is true for finished statuses" do
      %w[passed failed cancelled blocked].each do |status|
        expect(described_class.new(status: status)).to be_terminal
      end
    end

    it "is false while pending/running" do
      expect(described_class.new(status: "pending")).not_to be_terminal
      expect(described_class.new(status: "running")).not_to be_terminal
    end
  end

  describe "scopes" do
    it "orders newest first" do
      older = create(:pipeline, created_at: 1.day.ago)
      newer = create(:pipeline)
      expect(described_class.recent).to eq([newer, older])
    end

    it "scopes to a project" do
      project = create(:project)
      pipeline = create(:pipeline, project: project)
      create(:pipeline)
      expect(described_class.for_project(project)).to eq([pipeline])
    end
  end
end