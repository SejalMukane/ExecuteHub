require "rails_helper"

RSpec.describe JenkinsHttpClient do
  subject(:client) do
    described_class.new(
      base_url: base_url,
      username: "jenkins-bot",
      api_token: "secret-token",
      csrf_crumb_enabled: csrf_enabled,
      open_timeout: 5,
      read_timeout: 10
    )
  end

  let(:base_url) { "http://localhost:8080" }
  let(:csrf_enabled) { true }

  # Stub Net::HTTP so specs never make a real Jenkins request. Returns the
  # fake http double plus the accumulated requests array.
  def stub_jenkins_http(path_map)
    http = instance_double(Net::HTTP)
    requests = []
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:start) { |&blk| blk.call(http) }
    allow(http).to receive(:request) do |req|
      requests << req
      path_map.fetch(req.path) { raise "Unexpected Jenkins request: #{req.path}" }
    end
    [http, requests]
  end

  RESPONSE_CLASSES = {
    "200" => Net::HTTPOK,
    "401" => Net::HTTPUnauthorized,
    "403" => Net::HTTPForbidden,
    "404" => Net::HTTPNotFound,
    "429" => Net::HTTPTooManyRequests,
    "500" => Net::HTTPInternalServerError
  }.freeze

  def jenkins_response(status, body = nil)
    klass = RESPONSE_CLASSES.fetch(status.to_s, Net::HTTPResponse)
    resp = klass.new("1.1", status.to_s, status.to_s)
    resp.instance_variable_set(:@read, true)
    resp.instance_variable_set(:@body, body) unless body.nil?
    resp
  end

  describe "configuration" do
    it "raises when no Jenkins URL is set" do
      stub_jenkins_http({})
      expect do
        described_class.new(base_url: "", username: "u", api_token: "t").get("/foo")
      end.to raise_error(JenkinsHttpClient::ConfigurationError)
    end

    it "rejects a malformed base URL" do
      expect do
        described_class.new(base_url: "localhost:8080", username: "u", api_token: "t")
      end.to raise_error(JenkinsHttpClient::ConfigurationError, /http/)
    end
  end

  describe "GET" do
    it "sends an authenticated JSON request and parses the body" do
      _, requests = stub_jenkins_http(
        "/job/App/42/api/json" => jenkins_response(200, '{"number":42,"result":"SUCCESS"}')
      )

      data = client.get("/job/App/42/api/json")

      expect(data).to eq({ "number" => 42, "result" => "SUCCESS" })
      expect(requests.last.method).to eq("GET")
      expect(requests.last["Authorization"]).to be_present
      expect(requests.last["Authorization"]).to eq("Basic #{Base64.strict_encode64("jenkins-bot:secret-token")}")
      expect(requests.last["Accept"]).to eq("application/json")
    end

    it "does not fetch a crumb for safe GET requests" do
      http, requests = stub_jenkins_http(
        "/job/App/42/api/json" => jenkins_response(200, "{}")
      )

      client.get("/job/App/42/api/json")

      expect(requests.length).to eq(1)
      expect(http).to have_received(:request).once
    end

    it "maps 401 to UnauthorizedError" do
      stub_jenkins_http("/job/App/api/json" => jenkins_response(401))
      expect { client.get("/job/App/api/json") }.to raise_error(JenkinsHttpClient::UnauthorizedError, /401/)
    end

    it "maps 403 to ForbiddenError" do
      stub_jenkins_http("/job/App/api/json" => jenkins_response(403))
      expect { client.get("/job/App/api/json") }.to raise_error(JenkinsHttpClient::ForbiddenError)
    end

    it "maps 404 to NotFoundError" do
      stub_jenkins_http("/job/App/api/json" => jenkins_response(404))
      expect { client.get("/job/App/api/json") }.to raise_error(JenkinsHttpClient::NotFoundError)
    end

    it "maps 429 to RateLimitedError" do
      stub_jenkins_http("/job/App/api/json" => jenkins_response(429))
      expect { client.get("/job/App/api/json") }.to raise_error(JenkinsHttpClient::RateLimitedError)
    end

    it "maps 500 to ServerError" do
      stub_jenkins_http("/job/App/api/json" => jenkins_response(500))
      expect { client.get("/job/App/api/json") }.to raise_error(JenkinsHttpClient::ServerError)
    end

    it "maps timeout to TimeoutError" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:start).and_raise(Net::OpenTimeout)

      expect { client.get("/job/App/api/json") }.to raise_error(JenkinsHttpClient::TimeoutError)
    end

    it "maps connection failures to ConnectionError" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:start).and_raise(Errno::ECONNREFUSED)

      expect { client.get("/job/App/api/json") }.to raise_error(JenkinsHttpClient::ConnectionError)
    end
  end

  describe "POST with CSRF crumb" do
    it "fetches a crumb and attaches it before the POST" do
      _, requests = stub_jenkins_http(
        "/crumbIssuer/api/json" => jenkins_response(200, '{"crumb":"abc123","crumbRequestField":"Jenkins-Crumb"}'),
        "/job/App/build" => jenkins_response(200)
      )

      client.post("/job/App/build")

      crumb_req = requests[0]
      post_req = requests[1]
      expect(crumb_req.path).to eq("/crumbIssuer/api/json")
      expect(post_req.path).to eq("/job/App/build")
      expect(post_req["Jenkins-Crumb"]).to eq("abc123")
    end

    it "falls back to an uncrumbed POST when crumb issuance is disabled" do
      client = described_class.new(
        base_url: base_url, username: "u", api_token: "t", csrf_crumb_enabled: false
      )
      _, requests = stub_jenkins_http("/job/App/build" => jenkins_response(200))

      client.post("/job/App/build")

      expect(requests.length).to eq(1)
      expect(requests.first.path).to eq("/job/App/build")
    end

    it "sends form-encoded params via post_form" do
      _, requests = stub_jenkins_http(
        "/crumbIssuer/api/json" => jenkins_response(200, '{"crumb":"c1","crumbRequestField":"Jenkins-Crumb"}'),
        "/job/App/buildWithParameters" => jenkins_response(200)
      )

      client.post_form("/job/App/buildWithParameters", branch: "main")

      last = requests.last
      expect(last["Content-Type"]).to eq("application/x-www-form-urlencoded")
      expect(last.body).to include("branch=main")
    end
  end

  describe "DELETE" do
    it "sends a DELETE request" do
      _, requests = stub_jenkins_http(
        "/crumbIssuer/api/json" => jenkins_response(200, '{"crumb":"c1","crumbRequestField":"Jenkins-Crumb"}'),
        "/job/App/42/stop" => jenkins_response(200)
      )
      client.delete("/job/App/42/stop")
      expect(requests.last.method).to eq("DELETE")
    end
  end
end