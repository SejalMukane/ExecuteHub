require "rails_helper"

RSpec.describe TestResultBuilder, type: :service do
  describe ".persist" do
    let(:job) { create(:job, status: :completed) }

    it "creates a TestResult for every parsed test" do
      tests = [
        { title: "Login", file: "login.spec.ts", status: "passed", duration_ms: 1200, retry: 0 },
        { title: "Checkout", file: "checkout.spec.ts", status: "failed", duration_ms: 850,
          retry: 2, error_message: "Expected: success", stack_trace: "Error\n    at checkout.spec.ts:10",
          started_at: "2026-08-11T10:00:00Z" }
      ]

      expect { described_class.persist(job, tests, browser: "Chrome") }
        .to change(job.test_results, :count).by(2)

      passed = job.test_results.find_by!(status: "passed")
      expect(passed.test_name).to eq("Login")
      expect(passed.browser).to eq("Chrome")
      expect(passed.test_run_id).to eq(job.test_run_id)

      failed = job.test_results.find_by!(status: "failed")
      expect(failed.retry_count).to eq(2)
      expect(failed.error_message).to eq("Expected: success")
      expect(failed.stack_trace).to include("checkout.spec.ts:10")
      expect(failed.started_at).to eq(Time.utc(2026, 8, 11, 10, 0, 0))
      expect(failed.finished_at).to be_within(1).of(Time.utc(2026, 8, 11, 10, 0, 1))
    end

    it "returns zero when there are no tests" do
      expect(described_class.persist(job, [], browser: "Chrome")).to eq(0)
      expect(job.test_results.count).to eq(0)
    end

    it "broadcasts a test_result_completed event to the run and dashboard streams" do
      broadcasts = []
      allow(ActionCable.server).to receive(:broadcast) { |stream, payload| broadcasts << [stream, payload] }

      described_class.persist(job, [{ title: "One", file: "a.spec.ts", status: "passed", duration_ms: 10, retry: 0 }], browser: "Firefox")

      completed = broadcasts.select { |_, p| p[:type] == :test_result_completed }
      expect(completed.size).to eq(2)
      expect(completed.map(&:first)).to contain_exactly("test_run_#{job.test_run_id}", "dashboard")
      expect(completed.first.last[:test_result][:test_name]).to eq("One")
    end
  end
end
