require "rails_helper"

RSpec.describe TestResult, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:job) }
    it { is_expected.to belong_to(:test_run) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:test_name) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[passed failed skipped flaky]) }
    it { is_expected.to validate_numericality_of(:duration_ms).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:retry_count).is_greater_than_or_equal_to(0) }
  end

  describe "scopes" do
    it "filters by status" do
      run = create(:test_run)
      job = create(:job, test_run: run)
      passed = create(:test_result, job: job, test_run: run, status: :passed)
      failed = create(:test_result, job: job, test_run: run, status: :failed)
      skipped = create(:test_result, job: job, test_run: run, status: :skipped)
      flaky = create(:test_result, job: job, test_run: run, status: :flaky)

      expect(run.test_results.passed).to eq([passed])
      expect(run.test_results.failed).to eq([failed])
      expect(run.test_results.skipped).to eq([skipped])
      expect(run.test_results.flaky).to eq([flaky])
    end
  end

  describe "status helpers" do
    it "identifies failed and passed results" do
      expect(build(:test_result, status: :failed)).to be_failed
      expect(build(:test_result, status: :passed)).to be_passed
    end
  end
end
