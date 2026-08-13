require "rails_helper"

RSpec.describe DeploymentGateService do
  let(:project) { create(:project) }
  let(:pipeline) { create(:pipeline, project: project, status: :running) }
  let!(:build) { create(:build, project: project, pipeline: pipeline, jenkins_build_number: 5, status: :running) }
  let(:test_run) { create(:test_run, :completed, project: project, pipeline: pipeline) }

  before do
    create(:test_report, test_run: test_run, passed_tests: 100, failed_tests: 0, success_rate: 100.0)
  end

  def evaluate
    described_class.evaluate(test_run)
  end

  describe ".evaluate" do
    it "does nothing for a manual run without a pipeline" do
      run = create(:test_run, :completed, project: project)
      result = described_class.evaluate(run)
      expect(result.applied).to be(false)
      expect(result.gate).to be_nil
    end

    it "does nothing while the run is still running" do
      run = create(:test_run, project: project, pipeline: pipeline, status: :running)
      expect(described_class.evaluate(run).applied).to be(false)
    end

    it "auto-approves a passing run and passes the pipeline" do
      result = evaluate

      expect(result.applied).to be(true)
      expect(result.gate).to be_approved
      expect(pipeline.reload.status).to eq("passed")
    end

    it "leaves the gate pending when manual approval is required" do
      project.update!(release_policy: { "requires_manual_approval" => true })

      result = evaluate

      expect(result.gate.reload.status).to eq("pending")
      expect(result.gate.requires_approval).to be(true)
      expect(pipeline.reload.status).to eq("running")
    end

    it "blocks the gate for a failed run" do
      failed_run = create(:test_run, :failed, project: project, pipeline: pipeline)

      result = described_class.evaluate(failed_run)

      expect(result.gate).to be_blocked
      expect(result.gate.reason).to include("Test run failed")
      expect(pipeline.reload.status).to eq("blocked")
    end

    it "blocks the gate when the success rate is below the threshold" do
      test_run.test_report.update!(passed_tests: 80, failed_tests: 20, success_rate: 80.0)

      result = evaluate

      expect(result.gate).to be_blocked
      expect(pipeline.reload.status).to eq("blocked")
    end

    it "is safe to evaluate twice (no duplicate gates)" do
      described_class.evaluate(test_run)
      described_class.evaluate(test_run)

      expect(DeploymentGate.where(pipeline: pipeline).count).to eq(1)
    end

    it "updates the Jenkins build description with the outcome" do
      expect(JenkinsService).to receive(:set_build_description)
        .with(5, a_string_including("APPROVED"))
      evaluate
    end

    it "swallows Jenkins notification failures" do
      allow(JenkinsService).to receive(:set_build_description)
        .and_raise(JenkinsService::ConnectionError, "boom")

      expect { evaluate }.not_to raise_error
      expect(result_of(evaluate).gate).to be_approved
    end
  end

  def result_of(result)
    result
  end
end
