require "rails_helper"

RSpec.describe TestReportGenerator, type: :service do
  describe ".call" do
    it "aggregates test results into a single report for the run" do
      run = create(:test_run)
      job = create(:job, test_run: run, status: :completed)
      create(:test_result, job: job, test_run: run, status: :passed, duration_ms: 100)
      create(:test_result, job: job, test_run: run, status: :passed, duration_ms: 200)
      create(:test_result, job: job, test_run: run, status: :failed, duration_ms: 300)
      create(:test_result, job: job, test_run: run, status: :skipped, duration_ms: 0)
      create(:test_result, job: job, test_run: run, status: :flaky, duration_ms: 150)
      job.update!(duration_ms: 750)

      report = described_class.call(run)

      expect(report.total_tests).to eq(5)
      expect(report.passed_tests).to eq(2)
      expect(report.failed_tests).to eq(1)
      expect(report.skipped_tests).to eq(1)
      expect(report.flaky_tests).to eq(1)
      expect(report.duration_ms).to eq(750)
      expect(report.success_rate).to eq(40.0)
      expect(report.generated_at).to be_present
    end

    it "falls back to job counters when no parsed results exist" do
      run = create(:test_run)
      create(:job, test_run: run, status: :completed, passed_tests: 18, failed_tests: 2, duration_ms: 9000)

      report = described_class.call(run)

      expect(report.total_tests).to eq(20)
      expect(report.passed_tests).to eq(18)
      expect(report.failed_tests).to eq(2)
      expect(report.success_rate).to eq(90.0)
    end

    it "is idempotent — re-running upserts the same single report" do
      run = create(:test_run)
      create(:job, test_run: run, status: :completed, passed_tests: 10, failed_tests: 0)

      described_class.call(run)
      described_class.call(run)

      expect(TestReport.where(test_run_id: run.id).count).to eq(1)
      expect(run.reload.test_report.passed_tests).to eq(10)
    end

    it "computes a 0% success rate for an all-failed run" do
      run = create(:test_run)
      job = create(:job, test_run: run, status: :failed)
      create(:test_result, job: job, test_run: run, status: :failed, duration_ms: 500)

      report = described_class.call(run)

      expect(report.success_rate).to eq(0.0)
    end
  end
end
