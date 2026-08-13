require "rails_helper"

RSpec.describe JenkinsBuildStatusJob, type: :job do
  let(:project) { create(:project) }
  let(:pipeline) { create(:pipeline, project: project, status: :running) }
  let!(:build) { create(:build, project: project, pipeline: pipeline, status: :running) }

  before do
    allow(JenkinsService).to receive(:set_build_description)
    JenkinsBuildStatusJob.jobs.clear
  end

  def enqueued_jobs
    JenkinsBuildStatusJob.jobs
  end

  describe "#perform" do
    it "does nothing for an unknown build" do
      expect { described_class.new.perform(999_999) }.not_to change { enqueued_jobs.size }
    end

    it "does nothing for a build that is not running" do
      build.update!(status: :passed)
      expect { described_class.new.perform(build.id) }.not_to change { enqueued_jobs.size }
    end

    it "marks the build passed when Jenkins reports SUCCESS" do
      allow(JenkinsService).to receive(:build_status)
        .with(build.jenkins_build_number)
        .and_return({ number: build.jenkins_build_number, started_at: Time.current,
                      building: false, result: "SUCCESS", state: "passed" })

      expect { described_class.new.perform(build.id) }.not_to change { enqueued_jobs.size }
      expect(build.reload.status).to eq("passed")
      expect(build.finished_at).to be_present
    end

    it "passes the pipeline once the linked TestRun completes too" do
      run = create(:test_run, project: project, pipeline: pipeline, status: :queued, total_tests: 20)
      build.update!(test_run: run)
      create(:job, test_run: run, status: :completed, passed_tests: 20)
      allow(JenkinsService).to receive(:build_status)
        .and_return({ state: "passed", started_at: Time.current })

      described_class.new.perform(build.id)
      ResultAggregator.call(run)

      expect(run.reload.status).to eq("completed")
      expect(pipeline.reload.status).to eq("passed")
      expect(DeploymentGate.find_by(pipeline: pipeline)).to be_approved
    end

    it "fails the pipeline when Jenkins reports FAILURE" do
      run = create(:test_run, project: project, pipeline: pipeline, status: :running)
      build.update!(test_run: run)
      allow(JenkinsService).to receive(:build_status)
        .and_return({ state: "failed", started_at: Time.current })

      described_class.new.perform(build.id)

      expect(build.reload.status).to eq("failed")
      expect(pipeline.reload.status).to eq("failed")
      expect(run.reload.status).to eq("cancelled")
    end

    it "re-enqueues with exponential backoff while the build runs" do
      allow(JenkinsService).to receive(:build_status)
        .and_return({ state: "running", started_at: nil })

      described_class.new.perform(build.id, 1)

      jobs = enqueued_jobs
      expect(jobs.size).to eq(1)
      delay = jobs.first["at"].to_f - Time.now.to_f
      expect(delay).to be_between(4, 6)
      expect(jobs.first["args"]).to eq([build.id, 2])
    end

    it "doubles the backoff on the next attempt (up to 40s)" do
      allow(JenkinsService).to receive(:build_status)
        .and_return({ state: "running", started_at: nil })

      described_class.new.perform(build.id, 2)

      jobs = enqueued_jobs
      delay = jobs.first["at"].to_f - Time.now.to_f
      expect(delay).to be_between(9, 11)
      expect(jobs.first["args"]).to eq([build.id, 3])
    end

    it "caps the backoff at 40 seconds" do
      allow(JenkinsService).to receive(:build_status)
        .and_return({ state: "running", started_at: nil })

      described_class.new.perform(build.id, 5)

      jobs = enqueued_jobs
      delay = jobs.first["at"].to_f - Time.now.to_f
      expect(delay).to be_between(39, 41)
    end

    it "stops after the maximum number of attempts" do
      allow(JenkinsService).to receive(:build_status)
        .and_return({ state: "running", started_at: nil })

      described_class.new.perform(build.id, 30)

      expect(enqueued_jobs.size).to eq(0)
      expect(build.reload.status).to eq("running")
    end

    it "backs off (instead of crashing) when Jenkins is unreachable" do
      allow(JenkinsService).to receive(:build_status)
        .and_raise(JenkinsService::ConnectionError, "refused")

      described_class.new.perform(build.id, 1)

      expect(enqueued_jobs.size).to eq(1)
      expect(enqueued_jobs.first["args"]).to eq([build.id, 2])
    end
  end

  describe ".schedule" do
    it "enqueues the first poll against the configured interval" do
      described_class.schedule(build.id)

      jobs = enqueued_jobs
      expect(jobs.size).to eq(1)
      expect(jobs.first["args"]).to eq([build.id, 1])
    end
  end
end