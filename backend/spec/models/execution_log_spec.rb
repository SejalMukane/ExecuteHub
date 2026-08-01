require "rails_helper"

RSpec.describe ExecutionLog, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:job) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:message) }
    it { is_expected.to validate_inclusion_of(:level).in_array(%w[info warn error]) }
  end

  describe "timestamp stamping" do
    it "stamps the current time when none is provided" do
      log = build(:execution_log, timestamp: nil)
      expect(log.timestamp).to be_nil

      log.save!

      expect(log.reload.timestamp).to be_present
    end
  end

  describe "scopes" do
    it "orders logs chronologically (oldest first)" do
      job = create(:job)
      earlier = create(:execution_log, job: job, timestamp: 10.seconds.ago)
      later = create(:execution_log, job: job, timestamp: 2.seconds.ago)

      expect(job.execution_logs.chronological).to eq([earlier, later])
      expect(job.execution_logs.reverse_chronological).to eq([later, earlier])
    end
  end

  describe "job log integration" do
    it "records the full execution trail on the job" do
      job = create(:job)
      create_list(:execution_log, 3, job: job)

      expect(job.execution_logs.count).to eq(3)
    end
  end
end
