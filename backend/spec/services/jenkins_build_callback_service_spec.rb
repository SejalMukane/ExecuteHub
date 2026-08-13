require "rails_helper"

RSpec.describe JenkinsBuildCallbackService do
  let(:project) { create(:project) }
  let(:pipeline) { create(:pipeline, project: project, status: :running) }
  let(:build) { create(:build, project: project, pipeline: pipeline, status: :running, started_at: Time.current) }

  def call(status)
    described_class.call(build: build, jenkins_status: status)
  end

  describe ".call" do
    it "marks the build passed on SUCCESS" do
      result = call("SUCCESS")
      expect(result.applied).to be(true)
      expect(build.reload.status).to eq("passed")
      expect(build.finished_at).to be_present
    end

    it "marks the build failed on FAILURE and UNSTABLE" do
      expect(call("FAILURE").build.reload.status).to eq("failed")
      expect(call("UNSTABLE").build.reload.status).to eq("failed")
    end

    it "marks the build cancelled on ABORTED" do
      expect(call("ABORTED").build.reload.status).to eq("cancelled")
    end

    it "maps unrecognized statuses to error" do
      expect(call("banana").build.reload.status).to eq("error")
    end

    it "maps started/running to running" do
      build.update!(status: :pending)
      expect(call("STARTED").build.reload.status).to eq("running")
    end

    it "is idempotent for a repeated terminal webhook" do
      call("SUCCESS")
      expect(call("SUCCESS").applied).to be(false)
      expect(build.reload.status).to eq("passed")
    end

    it "cancels an in-flight TestRun and fails the pipeline on FAILURE" do
      run = create(:test_run, project: project, pipeline: pipeline, status: :running)
      build.update!(test_run: run)

      call("FAILURE")

      expect(build.reload.status).to eq("failed")
      expect(pipeline.reload.status).to eq("failed")
      expect(run.reload.status).to eq("cancelled")
      expect(run.finished_at).to be_present
    end

    it "marks the pipeline cancelled on ABORTED" do
      call("ABORTED")
      expect(pipeline.reload.status).to eq("cancelled")
    end

    it "leaves the TestRun and Pipeline running when the build passes" do
      run = create(:test_run, project: project, pipeline: pipeline, status: :running)
      build.update!(test_run: run)

      call("SUCCESS")

      expect(build.reload.status).to eq("passed")
      expect(pipeline.reload.status).to eq("running")
      expect(run.reload.status).to eq("running")
    end

    it "swallows notification failures and still applies the transition" do
      allow(NotificationService).to receive(:notify).and_raise(StandardError, "boom")

      expect { call("FAILURE") }.not_to raise_error
      expect(build.reload.status).to eq("failed")
      expect(pipeline.reload.status).to eq("failed")
    end

    it "swallows notification failures when the pipeline is cancelled" do
      allow(NotificationService).to receive(:notify).and_raise(StandardError, "boom")

      expect { call("ABORTED") }.not_to raise_error
      expect(build.reload.status).to eq("cancelled")
      expect(pipeline.reload.status).to eq("cancelled")
    end
  end
end
