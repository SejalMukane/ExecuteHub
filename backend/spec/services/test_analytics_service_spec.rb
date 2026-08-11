require "rails_helper"

RSpec.describe TestAnalyticsService, type: :service do
  let(:project) { create(:project) }

  def build_run(project:, passed:, failed:, skipped: 0, flaky: 0, duration_ms: 5000, days_ago: 0)
    run = create(:test_run, project: project, status: :completed, created_at: days_ago.days.ago,
      total_tests: passed + failed + skipped, passed_tests: passed, failed_tests: failed,
      total_duration_ms: duration_ms)
    job = create(:job, test_run: run, status: :completed, duration_ms: duration_ms)
    passed.times { create(:test_result, job: job, test_run: run, status: :passed, duration_ms: 100) }
    failed.times { create(:test_result, job: job, test_run: run, status: :failed, duration_ms: 200) }
    skipped.times { create(:test_result, job: job, test_run: run, status: :skipped, duration_ms: 0) }
    flaky.times { create(:test_result, job: job, test_run: run, status: :flaky, duration_ms: 150) }
    run
  end

  describe ".for_test_run" do
    it "reports success/failure rates, counts and durations for one run" do
      build_run(project: project, passed: 95, failed: 3, skipped: 2, duration_ms: 10_000)

      run = project.test_runs.first
      analytics = described_class.for_test_run(run)

      expect(analytics[:overview][:tests_executed]).to eq(100)
      expect(analytics[:overview][:tests_passed]).to eq(95)
      expect(analytics[:overview][:tests_failed]).to eq(3)
      expect(analytics[:overview][:tests_skipped]).to eq(2)
      expect(analytics[:overview][:success_rate]).to eq(95.0)
      expect(analytics[:overview][:failure_rate]).to eq(3.0)
      expect(analytics[:overview][:average_execution_duration_ms]).to eq(10_000.0)
      expect(analytics[:overview][:average_test_duration_ms]).to eq(101.0)
    end
  end

  describe ".for_project" do
    it "aggregates tests across all runs and computes rates" do
      build_run(project: project, passed: 90, failed: 10, days_ago: 1)
      build_run(project: project, passed: 95, failed: 3, skipped: 2, days_ago: 2)

      analytics = described_class.for_project(project, days: 30)

      overview = analytics[:overview]
      expect(overview[:tests_executed]).to eq(200)
      expect(overview[:tests_passed]).to eq(185)
      expect(overview[:tests_failed]).to eq(13)
      expect(overview[:tests_skipped]).to eq(2)
      expect(overview[:total_test_runs]).to eq(2)
      expect(overview[:success_rate]).to eq(92.5)
      expect(overview[:failure_rate]).to eq(6.5)
    end

    it "reports flaky tests and retry rate" do
      build_run(project: project, passed: 8, failed: 0, flaky: 2)
      run = project.test_runs.first
      run.jobs.first.update!(retry_count: 1)

      overview = described_class.for_project(project, days: 30)[:overview]

      expect(overview[:flaky_test_count]).to eq(2)
      expect(overview[:retry_rate]).to eq(100.0)
    end

    it "builds success-rate time series grouped by day" do
      build_run(project: project, passed: 90, failed: 10, days_ago: 1)
      build_run(project: project, passed: 50, failed: 50, days_ago: 1)

      history = described_class.for_project(project, days: 30)[:history]
      series = history[:success_rate_over_time]

      expect(series.length).to eq(1)
      expect(series.first[:success_rate]).to eq(70.0)
    end

    it "ranks the most frequently failing tests and suites" do
      run = build_run(project: project, passed: 1, failed: 0)
      job = run.jobs.first
      3.times { create(:test_result, job: job, test_run: run, status: :failed, test_name: "checkout fails", suite_name: "checkout.spec.ts") }
      3.times { create(:test_result, job: job, test_run: run, status: :failed, test_name: "login fails", suite_name: "login.spec.ts") }

      history = described_class.for_project(project, days: 30)[:history]

      expect(history[:most_failing_tests].first[:name]).to eq("checkout fails")
      expect(history[:most_failing_tests].first[:count]).to eq(3)
      expect(history[:most_failing_suites].map { |row| row[:name] })
        .to contain_exactly("checkout.spec.ts", "login.spec.ts")
    end

    it "computes tests executed per day from run totals" do
      build_run(project: project, passed: 40, failed: 0, days_ago: 1)

      history = described_class.for_project(project, days: 30)[:history]

      expect(history[:tests_executed_per_day].first[:tests_executed]).to eq(40)
    end
  end

  describe ".global" do
    it "aggregates across every project" do
      other_project = create(:project)
      build_run(project: project, passed: 10, failed: 0)
      build_run(project: other_project, passed: 5, failed: 5)

      overview = described_class.global(days: 30)[:overview]

      expect(overview[:tests_executed]).to eq(20)
      expect(overview[:tests_passed]).to eq(15)
      expect(overview[:tests_failed]).to eq(5)
    end
  end
end
