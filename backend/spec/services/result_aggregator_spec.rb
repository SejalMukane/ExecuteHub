require "rails_helper"

RSpec.describe ResultAggregator, type: :service do
  describe ".call" do
    context "when not every job is terminal" do
      it "does nothing while jobs are still running or queued" do
        test_run = create(:test_run)
        create(:job, test_run: test_run, status: :completed, passed_tests: 10, failed_tests: 0)
        create(:job, test_run: test_run, status: :running)

        expect { described_class.call(test_run) }.not_to change { test_run.reload.status }
        expect(test_run.passed_tests).to eq(0)
      end

      it "returns the run without marking it terminal" do
        test_run = create(:test_run)
        create(:job, test_run: test_run, status: :queued)

        described_class.call(test_run)

        expect(test_run.reload.status).to eq("queued")
        expect(test_run.finished_at).to be_nil
      end
    end

    context "when every job is terminal" do
      it "sums passed and failed tests across all jobs" do
        test_run = create(:test_run)
        create(:job, test_run: test_run, status: :completed, passed_tests: 18, failed_tests: 2)
        create(:job, test_run: test_run, status: :completed, passed_tests: 20, failed_tests: 0)

        described_class.call(test_run)

        test_run.reload
        expect(test_run.passed_tests).to eq(38)
        expect(test_run.failed_tests).to eq(2)
      end

      it "sums total duration from every job" do
        test_run = create(:test_run)
        create(:job, test_run: test_run, status: :completed, duration_ms: 1000)
        create(:job, test_run: test_run, status: :completed, duration_ms: 2500)

        described_class.call(test_run)

        expect(test_run.reload.total_duration_ms).to eq(3500)
      end

      it "counts screenshots and videos produced by every job" do
        test_run = create(:test_run)
        job_a = create(:job, test_run: test_run, status: :completed)
        job_b = create(:job, test_run: test_run, status: :completed)
        create(:artifact, job: job_a, artifact_type: "screenshot")
        create(:artifact, job: job_a, artifact_type: "screenshot")
        create(:artifact, job: job_b, artifact_type: "video")
        create(:artifact, job: job_b, artifact_type: "trace")

        described_class.call(test_run)

        test_run.reload
        expect(test_run.total_screenshots).to eq(2)
        expect(test_run.total_videos).to eq(1)
      end

      it "marks the run completed when no job failed" do
        test_run = create(:test_run)
        create(:job, test_run: test_run, status: :completed, passed_tests: 40)

        described_class.call(test_run)

        test_run.reload
        expect(test_run.status).to eq("completed")
        expect(test_run.finished_at).to be_present
      end

      it "marks the run failed when any job failed" do
        test_run = create(:test_run)
        create(:job, test_run: test_run, status: :completed, passed_tests: 20)
        create(:job, test_run: test_run, status: :failed, failed_tests: 5)

        described_class.call(test_run)

        test_run.reload
        expect(test_run.status).to eq("failed")
        expect(test_run.failed_tests).to eq(5)
      end

      it "is idempotent — calling twice produces the same summary" do
        test_run = create(:test_run)
        create(:job, test_run: test_run, status: :completed, passed_tests: 20)

        2.times { described_class.call(test_run) }

        expect(test_run.reload.passed_tests).to eq(20)
        expect(test_run.status).to eq("completed")
      end

      it "does nothing when the run has no jobs" do
        test_run = create(:test_run)

        expect { described_class.call(test_run) }.not_to change { test_run.reload.status }
      end

      it "generates the aggregate test report once every job is terminal" do
        test_run = create(:test_run, status: :queued, total_tests: 40)
        job = create(:job, test_run: test_run, status: :completed, passed_tests: 38, failed_tests: 2)
        create(:test_result, job: job, test_run: test_run, status: :passed)
        create(:test_result, job: job, test_run: test_run, status: :passed)
        create(:test_result, job: job, test_run: test_run, status: :failed)

        described_class.call(test_run)

        report = test_run.reload.test_report
        expect(report).to be_present
        expect(report.total_tests).to eq(3)
        expect(report.passed_tests).to eq(2)
        expect(report.failed_tests).to eq(1)
      end

      it "falls back to job counters when no test results exist" do
        test_run = create(:test_run, status: :queued)
        create(:job, test_run: test_run, status: :completed, passed_tests: 20, failed_tests: 5)

        described_class.call(test_run)

        report = test_run.reload.test_report
        expect(report.total_tests).to eq(25)
        expect(report.failed_tests).to eq(5)
      end

      it "evaluates the release gate for a CI run and passes the pipeline" do
        pipeline = create(:pipeline, status: :running)
        test_run = create(:test_run, project: pipeline.project, pipeline: pipeline, status: :queued)
        create(:job, test_run: test_run, status: :completed, passed_tests: 40)
        allow(JenkinsService).to receive(:set_build_description)

        described_class.call(test_run)

        expect(test_run.reload.status).to eq("completed")
        expect(pipeline.reload.status).to eq("passed")
        expect(DeploymentGate.find_by(pipeline: pipeline)).to be_approved
      end

      it "blocks the pipeline when a CI run fails" do
        pipeline = create(:pipeline, status: :running)
        test_run = create(:test_run, project: pipeline.project, pipeline: pipeline, status: :queued)
        create(:job, test_run: test_run, status: :failed, failed_tests: 5)
        allow(JenkinsService).to receive(:set_build_description)

        described_class.call(test_run)

        expect(test_run.reload.status).to eq("failed")
        expect(pipeline.reload.status).to eq("blocked")
      end

      it "does not create a gate for manual runs" do
        test_run = create(:test_run, status: :queued)
        create(:job, test_run: test_run, status: :completed, passed_tests: 40)

        described_class.call(test_run)

        expect(DeploymentGate.where(test_run: test_run)).to be_empty
      end
    end
  end
end
