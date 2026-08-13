require "rails_helper"

RSpec.describe "Builds API", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, role: :developer, team: team) }
  let(:headers) { auth_headers_for(user) }
  let(:project) { create(:project, user: user, team: team) }
  let(:pipeline) { create(:pipeline, project: project) }

  describe "GET /api/v1/builds" do
    it "lists visible builds newest first" do
      newer = create(:build, project: project, pipeline: pipeline, created_at: 1.day.ago)
      older = create(:build, project: project, pipeline: pipeline, created_at: 2.days.ago)
      create(:build, project: create(:project))

      get "/api/v1/builds", headers: headers

      expect(response).to have_http_status(:ok)
      builds = JSON.parse(response.body)["builds"]
      expect(builds.map { |b| b["id"] }).to eq([newer.id, older.id])
    end

    it "filters by project and status" do
      running = create(:build, project: project, pipeline: pipeline, status: :running)
      create(:build, project: project, pipeline: pipeline, status: :passed)

      get "/api/v1/builds?project_id=#{project.id}&status=running", headers: headers

      builds = JSON.parse(response.body)["builds"]
      expect(builds.map { |b| b["id"] }).to eq([running.id])
    end
  end

  describe "GET /api/v1/builds/:id" do
    it "returns a single build with its duration" do
      build = create(:build, project: project, pipeline: pipeline, status: :running,
                             started_at: 10.seconds.ago)
      build.finish!(:passed)

      get "/api/v1/builds/#{build.id}", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)["build"]
      expect(body["status"]).to eq("passed")
      expect(body["duration"]).to be_present
      expect(body["duration_seconds"]).to be_present
    end

    it "404s for a build the user cannot access" do
      get "/api/v1/builds/#{create(:build).id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end