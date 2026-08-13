require "rails_helper"

RSpec.describe CiTriggerService do
  let(:project) { create(:project) }
  let(:attrs) do
    {
      project: project,
      branch: "main",
      commit_sha: "a" * 40,
      jenkins_build_number: 12,
      job_name: "executehub-tests"
    }
  end

  describe ".call" do
    it "creates a Pipeline, a Build and a scheduled TestRun" do
      result = described_class.call(**attrs, total_tests: 100)

      expect(result.created).to be(true)
      expect(result.pipeline).to be_persisted
      expect(result.pipeline.ci_key).to eq("jenkins:executehub-tests:12")
      expect(result.pipeline.provider).to eq("jenkins")
      expect(result.pipeline.status).to eq("running")
      expect(result.pipeline.branch).to eq("main")

      expect(result.build).to be_persisted
      expect(result.build.status).to eq("running")
      expect(result.build.pipeline).to eq(result.pipeline)
      expect(result.build.test_run).to eq(result.test_run)

      expect(result.test_run).to be_persisted
      expect(result.test_run.total_tests).to eq(100)
      expect(result.test_run.total_jobs).to eq(5)
      expect(result.test_run.pipeline).to eq(result.pipeline)
    end

    it "is idempotent for a retried Jenkins build" do
      first = described_class.call(**attrs, total_tests: 100)

      expect {
        second = described_class.call(**attrs, total_tests: 100)
        expect(second.created).to be(false)
        expect(second.pipeline).to eq(first.pipeline)
        expect(second.build).to eq(first.build)
        expect(second.test_run).to eq(first.test_run)
      }.to change(Pipeline, :count).by(0)
       .and change(Build, :count).by(0)
       .and change(TestRun, :count).by(0)
       .and change(Job, :count).by(0)
    end

    it "uses the config default total_tests when none is given" do
      result = described_class.call(**attrs)
      expect(result.test_run.total_tests).to eq(20)
    end

    it "uses the test suite count when a suite id is given" do
      suite = create(:test_suite, total_tests: 60)
      result = described_class.call(**attrs, test_suite_id: suite.id)
      expect(result.test_run.total_tests).to eq(60)
    end

    it "lets an explicit total_tests override the suite" do
      suite = create(:test_suite, total_tests: 60)
      result = described_class.call(**attrs, test_suite_id: suite.id, total_tests: 200)
      expect(result.test_run.total_tests).to eq(200)
    end

    it "raises for an unknown suite" do
      expect { described_class.call(**attrs, test_suite_id: 999_999) }
        .to raise_error(CiTriggerService::InvalidParameters, /not found/)
    end

    it "raises when required fields are missing" do
      expect { described_class.call(**attrs.merge(branch: nil)) }
        .to raise_error(CiTriggerService::InvalidParameters, /branch/)
      expect { described_class.call(**attrs.merge(commit_sha: nil)) }
        .to raise_error(CiTriggerService::InvalidParameters, /commit_sha/)
      expect { described_class.call(**attrs.merge(jenkins_build_number: 0)) }
        .to raise_error(CiTriggerService::InvalidParameters, /jenkins_build_number/)
    end
  end
end