require "rails_helper"

RSpec.describe "Pipelines API", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, role: :developer, team: team) }
  let(:headers) { auth_headers_for(user) }
  let(:project) { create(:project, user: user, team: team) }
  let(:pipeline) { create(:pipeline, project: project, status: :running) }

  before { ENV["JENKINS_JOB_NAME"] = "ExecuteHub-App" }

  describe "GET /api/v1/pipelines" do
    it "lists visible pipelines newest first with gate summary" do
      older = create(:pipeline, project: project, created_at: 2.days.ago)
      gate = create(:deployment_gate, project: project, pipeline: pipeline, status: :pending)
      create(:build, project: project, pipeline: pipeline)

      get "/api/v1/pipelines", headers: headers

      expect(response).to have_http_status(:ok)
      pipelines = JSON.parse(response.body)["pipelines"]
      expect(pipelines.first["id"]).to eq(pipeline.id)
      expect(pipelines.map { |p| p["id"] }).to include(older.id)
      latest = pipelines.find { |p| p["id"] == pipeline.id }
      expect(latest["gate_status"]).to eq("pending")
      expect(latest["build_count"]).to eq(1)
    end

    it "filters by project and status" do
      other = create(:pipeline, project: create(:project))
      passed = create(:pipeline, project: project, status: :passed)
      branch = pipeline

      get "/api/v1/pipelines?project_id=#{project.id}&status=running", headers: headers

      pipelines = JSON.parse(response.body)["pipelines"]
      expect(pipelines.map { |p| p["id"] }).to eq([branch.id])
      expect(pipelines.map { |p| p["id"] }).not_to include(other.id, passed.id)
    end

    it "requires authentication" do
      get "/api/v1/pipelines"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/pipelines/:id" do
    it "returns the pipeline with builds, test runs and gate" do
      build = create(:build, project: project, pipeline: pipeline)
      run = create(:test_run, project: project, pipeline: pipeline, status: :completed)
      gate = create(:deployment_gate, project: project, pipeline: pipeline, test_run: run, status: :approved)

      get "/api/v1/pipelines/#{pipeline.id}", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["builds"].map { |b| b["id"] }).to eq([build.id])
      expect(body["test_runs"].map { |r| r["id"] }).to eq([run.id])
      expect(body["deployment_gate"]["status"]).to eq("approved")
      expect(body["builds"].first["url"]).to include("/job/ExecuteHub-App/")
    end

    it "404s for a pipeline the user cannot access" do
      get "/api/v1/pipelines/#{create(:pipeline).id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/pipelines/:id/status" do
    it "returns the pipeline, latest run progress and gate" do
      run = create(:test_run, project: project, pipeline: pipeline, status: :running,
                              total_jobs: 2, completed_jobs: 1, progress_percentage: 50.0)

      get "/api/v1/pipelines/#{pipeline.id}/status", headers: headers

      body = JSON.parse(response.body)
      expect(body["pipeline"]["status"]).to eq("running")
      expect(body["test_run_progress"]["progress_percentage"]).to eq(50.0)
    end

    it "accepts a project CI token so Jenkins can poll the gate" do
      _, ci_token = CiApiTokenService.create!(project: project, name: "Jenkins")

      get "/api/v1/pipelines/#{pipeline.id}/status",
          headers: { "Authorization" => "Bearer #{ci_token}" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["pipeline"]["id"]).to eq(pipeline.id)
    end

    it "supports the X-ExecuteHub-Token header" do
      _, ci_token = CiApiTokenService.create!(project: project, name: "Jenkins")

      get "/api/v1/pipelines/#{pipeline.id}/status",
          headers: { "X-ExecuteHub-Token" => ci_token }

      expect(response).to have_http_status(:ok)
    end

    it "404s (not 200) when a CI token polls another project's pipeline" do
      _, ci_token = CiApiTokenService.create!(project: project, name: "Jenkins")
      other = create(:pipeline)

      get "/api/v1/pipelines/#{other.id}/status",
          headers: { "Authorization" => "Bearer #{ci_token}" }

      expect(response).to have_http_status(:not_found)
    end

    it "rejects an invalid CI token" do
      get "/api/v1/pipelines/#{pipeline.id}/status",
          headers: { "Authorization" => "Bearer nope" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
