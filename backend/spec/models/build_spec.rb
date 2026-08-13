require "rails_helper"

RSpec.describe Build, type: :model do
  subject(:record) { create(:build) }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:pipeline).optional }
  it { is_expected.to belong_to(:test_run).optional }

  it { is_expected.to validate_presence_of(:jenkins_build_number) }
  it { is_expected.to validate_presence_of(:jenkins_job_name) }
  it { is_expected.to validate_presence_of(:branch) }

  describe "idempotency" do
    it "rejects the same job + build number twice for a project" do
      project = create(:project)
      create(:build, project: project, jenkins_job_name: "Fanfare", jenkins_build_number: 7)
      duplicate = build(:build, project: project, jenkins_job_name: "Fanfare", jenkins_build_number: 7)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:jenkins_build_number]).to include(/already exists/)
    end

    it "allows the same build number across different jobs" do
      project = create(:project)
      create(:build, project: project, jenkins_job_name: "Job-A", jenkins_build_number: 7)
      expect(build(:build, project: project, jenkins_job_name: "Job-B", jenkins_build_number: 7)).to be_valid
    end
  end

  describe "lifecycle" do
    it "marks a build running with a started_at" do
      record.mark_running!
      expect(record.status).to eq("running")
      expect(record.started_at).to be_present
    end

    it "finishes a build with a duration" do
      record.mark_running!
      travel 2.seconds
      record.reload
      record.finish!(:passed)

      expect(record.status).to eq("passed")
      expect(record.finished_at).to be_present
      expect(record.duration).to be > 0
      expect(record.duration_seconds).to be > 0
    end
  end

  describe "#terminal?" do
    it "is true for finished statuses" do
      %w[passed failed cancelled error].each do |status|
        expect(described_class.new(status: status)).to be_terminal
      end
    end
  end
end