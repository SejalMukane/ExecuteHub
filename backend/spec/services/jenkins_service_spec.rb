require "rails_helper"

RSpec.describe JenkinsService do
  # JenkinsService reads credentials from the environment, so we pin them per
  # example and restore afterwards so other specs are unaffected.
  around do |example|
    old = {
      "JENKINS_URL" => ENV["JENKINS_URL"],
      "JENKINS_USERNAME" => ENV["JENKINS_USERNAME"],
      "JENKINS_API_TOKEN" => ENV["JENKINS_API_TOKEN"],
      "JENKINS_JOB_NAME" => ENV["JENKINS_JOB_NAME"]
    }
    ENV["JENKINS_URL"] = "http://localhost:8080"
    ENV["JENKINS_USERNAME"] = "jenkins-bot"
    ENV["JENKINS_API_TOKEN"] = "secret-token"
    ENV["JENKINS_JOB_NAME"] = "ExecuteHub-App"
    example.run
  ensure
    old.each { |key, value| ENV[key] = value }
  end

  # A fake client records the calls it receives and returns canned responses,
  # so JenkinsService can be tested without any real Jenkins request.
  let(:client) { instance_double(JenkinsHttpClient) }

  describe ".configured?" do
    it "is true when credentials are present" do
      expect(described_class.configured?).to be(true)
    end

    it "is false when the URL is missing" do
      ENV["JENKINS_URL"] = ""
      expect(described_class.configured?).to be(false)
    end
  end

  describe ".trigger_build" do
    it "POSTs to the job's build endpoint without params" do
      allow(client).to receive(:post).and_return(nil)

      result = described_class.trigger_build(client: client)

      expect(client).to have_received(:post).with("/job/ExecuteHub-App/build")
      expect(result[:job]).to eq("ExecuteHub-App")
    end

    it "POSTs form-encoded params to buildWithParameters" do
      allow(client).to receive(:post_form).and_return(nil)

      described_class.trigger_build(params: { branch: "main", commit: "abc" }, client: client)

      expect(client).to have_received(:post_form).with(
        "/job/ExecuteHub-App/buildWithParameters",
        { "branch" => "main", "commit" => "abc" }
      )
    end

    it "raises when no job name is configured" do
      ENV["JENKINS_JOB_NAME"] = ""
      expect { described_class.trigger_build(client: client) }
        .to raise_error(JenkinsService::ConfigurationError, /JENKINS_JOB_NAME/)
    end
  end

  describe ".build_status" do
    it "normalizes a running build" do
      allow(client).to receive(:get).and_return(
        { "number" => 42, "building" => true, "timestamp" => 1_700_000_000_000, "duration" => 0, "url" => "http://x/job/App/42/" }
      )

      status = described_class.build_status(42, client: client)

      expect(status[:state]).to eq("running")
      expect(status[:building]).to be(true)
    end

    it "maps Jenkins results to Build states" do
      {
        "SUCCESS" => "passed",
        "FAILURE" => "failed",
        "UNSTABLE" => "failed",
        "ABORT" => "cancelled",
        "NOT_BUILT" => "error",
        nil => "error"
      }.each do |result, expected|
        allow(client).to receive(:get).and_return(
          { "number" => 7, "building" => false, "result" => result }
        )
        expect(described_class.build_status(7, client: client)[:state]).to eq(expected)
      end
    end

    it "converts the Jenkins timestamp (ms) into a Time" do
      allow(client).to receive(:get).and_return(
        { "number" => 1, "building" => false, "result" => "SUCCESS", "timestamp" => 1_700_000_000_000 }
      )

      expect(described_class.build_status(1, client: client)[:started_at]).to be_a(Time)
    end
  end

  describe ".build_info" do
    it "delegates to the client and returns raw JSON" do
      allow(client).to receive(:get).and_return({ "number" => 42 })
      expect(described_class.build_info(42, client: client)).to eq({ "number" => 42 })
      expect(client).to have_received(:get).with("/job/ExecuteHub-App/42/api/json")
    end
  end

  describe ".cancel_build" do
    it "POSTs to the build stop endpoint" do
      allow(client).to receive(:post).and_return(nil)
      expect(described_class.cancel_build(42, client: client)).to eq({ cancelled: 42 })
      expect(client).to have_received(:post).with("/job/ExecuteHub-App/42/stop")
    end
  end

  describe ".set_build_description" do
    it "posts the description as form data" do
      allow(client).to receive(:post_form).and_return(nil)
      described_class.set_build_description(42, "ExecuteHub: passed", client: client)
      expect(client).to have_received(:post_form).with(
        "/job/ExecuteHub-App/42/submitDescription", description: "ExecuteHub: passed"
      )
    end

    it "swallows 404/403 so read-only tokens never break the pipeline" do
      allow(client).to receive(:post_form).and_raise(JenkinsService::NotFoundError)
      expect { described_class.set_build_description(42, "x", client: client) }.not_to raise_error
    end
  end

  describe "error propagation" do
    it "re-raises Jenkins API errors to the caller" do
      allow(client).to receive(:get).and_raise(JenkinsService::UnauthorizedError)
      expect { described_class.build_status(42, client: client) }
        .to raise_error(JenkinsService::UnauthorizedError)
    end
  end
end