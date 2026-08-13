require "rails_helper"

RSpec.describe "Ci::Jenkins trigger API", type: :request do
  let(:project) { create(:project) }
  let!(:token) { CiApiTokenService.create!(project: project, name: "Jenkins").last }
  let(:ci_headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }
  let(:payload) do
    {
      project_id: project.id,
      branch: "main",
      commit_sha: "b" * 40,
      jenkins_build_number: 42,
      job_name: "executehub-tests",
      total_tests: 40
    }
  end

  describe "POST /api/v1/ci/jenkins/test_runs" do
    it "creates the pipeline/build/test_run and returns 201" do
      expect {
        post "/api/v1/ci/jenkins/test_runs", params: payload.to_json, headers: ci_headers
      }.to change(Pipeline, :count).by(1)
       .and change(Build, :count).by(1)
       .and change(TestRun, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["pipeline"]["ci_key"]).to eq("jenkins:executehub-tests:42")
      expect(body["pipeline"]["status"]).to eq("running")
      expect(body["build"]["jenkins_build_number"]).to eq(42)
      expect(body["test_run"]["total_tests"]).to eq(40)
      expect(body["test_run"]["total_jobs"]).to eq(2)
    end

    it "is idempotent — a retried build returns 200 and no new records" do
      post "/api/v1/ci/jenkins/test_runs", params: payload.to_json, headers: ci_headers
      expect(response).to have_http_status(:created)

      expect {
        post "/api/v1/ci/jenkins/test_runs", params: payload.to_json, headers: ci_headers
      }.to change(Pipeline, :count).by(0)
       .and change(Build, :count).by(0)
       .and change(TestRun, :count).by(0)
       .and change(Job, :count).by(0)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["pipeline"]["status"]).to eq("running")
      expect(body["test_run"]["total_jobs"]).to eq(2)
    end

    it "supports the X-ExecuteHub-Token header" do
      headers = { "X-ExecuteHub-Token" => token, "Content-Type" => "application/json" }
      post "/api/v1/ci/jenkins/test_runs", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:created)
    end

    it "rejects requests without a token" do
      post "/api/v1/ci/jenkins/test_runs", params: payload.to_json
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an invalid token" do
      post "/api/v1/ci/jenkins/test_runs", params: payload.to_json,
           headers: { "Authorization" => "Bearer nope" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "forbids using another project's token" do
      other = create(:project)
      post "/api/v1/ci/jenkins/test_runs",
           params: payload.merge(project_id: other.id).to_json, headers: ci_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 for an unknown project" do
      post "/api/v1/ci/jenkins/test_runs",
           params: payload.merge(project_id: 999_999).to_json, headers: ci_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 for invalid parameters" do
      post "/api/v1/ci/jenkins/test_runs",
           params: payload.merge(branch: nil).to_json, headers: ci_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end