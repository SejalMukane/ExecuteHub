require "rails_helper"

RSpec.describe ReleaseGateService do
  let(:project) { create(:project) }
  let(:test_run) { create(:test_run, :completed, project: project) }

  describe ".call" do
    context "when the TestRun is incomplete" do
      it "blocks a queued run" do
        run = create(:test_run, status: :queued)
        result = described_class.call(run)

        expect(result).to be_blocked
        expect(result.reason).to include("incomplete")
      end

      it "blocks a completed run without a report" do
        run = create(:test_run, status: :completed, finished_at: Time.current)
        expect(described_class.call(run)).to be_blocked
      end
    end

    context "when the run passed" do
      before do
        create(:test_report, test_run: test_run, passed_tests: 100, failed_tests: 0, success_rate: 100.0)
      end

      it "approves the release" do
        result = described_class.call(test_run)
        expect(result).to be_approved
        expect(result.status).to eq(:approved)
      end
    end

    context "success rate below threshold" do
      before do
        create(:test_report, test_run: test_run, passed_tests: 80, failed_tests: 20, success_rate: 80.0)
      end

      it "blocks when 80% is under the 95% default" do
        result = described_class.call(test_run)
        expect(result).to be_blocked
        expect(result.reason).to include("80.0%")
        expect(result.reason).to include("95.0%")
      end

      it "honours a project-level threshold override" do
        project.update!(release_policy: { "minimum_success_rate" => 75 })
        expect(described_class.call(test_run)).to be_approved
      end
    end

    context "required suite" do
      let(:suite) { create(:test_suite, name: "Checkout") }

      before do
        test_run.update!(test_suite: suite)
        create(:test_report, test_run: test_run, passed_tests: 100, failed_tests: 0, success_rate: 100.0)
      end

      it "blocks when a required suite never ran" do
        project.update!(release_policy: { "required_suites" => ["Checkout", "Regression"] })
        result = described_class.call(test_run)

        expect(result).to be_blocked
        expect(result.reason).to include("Regression")
      end

      it "approves when the required suite ran and passed" do
        project.update!(release_policy: { "required_suites" => ["Checkout"] })
        expect(described_class.call(test_run)).to be_approved
      end

      it "blocks when a required suite has a failed test" do
        project.update!(release_policy: { "required_suites" => ["Checkout"] })
        job = create(:job, test_run: test_run)
        create(:test_result, test_run: test_run, job: job,
               suite_name: "Checkout", test_name: "buy item", status: "failed")

        result = described_class.call(test_run)

        expect(result).to be_blocked
        expect(result.reason).to include("Critical test")
        expect(result.reason).to include("buy item")
      end

      it "does not treat failures outside required suites as critical" do
        project.update!(release_policy: { "required_suites" => ["Checkout"] })
        job = create(:job, test_run: test_run)
        create(:test_result, test_run: test_run, job: job,
               suite_name: "examples.spec.ts", test_name: "boring test", status: "failed")
        test_run.test_report.update!(passed_tests: 99, failed_tests: 1, success_rate: 99.0)

        expect(described_class.call(test_run)).to be_approved
      end
    end

    context "when no tests executed" do
      it "blocks with a 0% success rate" do
        create(:test_report, test_run: test_run, passed_tests: 0, failed_tests: 0, success_rate: 0.0)
        expect(described_class.call(test_run)).to be_blocked
      end
    end

    context "Result shape" do
      it "exposes a hash payload" do
        result = described_class.call(test_run)
        expect(result.to_h).to eq({ status: result.status, reason: result.reason, approved: result.approved? })
      end
    end
  end

  describe "policy defaults" do
    it "reads the global minimum_success_rate default" do
      expect(described_class.new(test_run).minimum_success_rate).to eq(95.0)
    end

    it "lets project policy override the default" do
      project.update!(release_policy: { "minimum_success_rate" => 90 })
      expect(described_class.new(test_run).minimum_success_rate).to eq(90.0)
    end
  end
end