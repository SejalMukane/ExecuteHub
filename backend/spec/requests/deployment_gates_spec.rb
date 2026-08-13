require "rails_helper"

RSpec.describe "DeploymentGates API", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, role: :developer, team: team) }
  let(:headers) { auth_headers_for(user) }
  let(:project) { create(:project, user: user, team: team) }
  let(:pipeline) { create(:pipeline, project: project, status: :running) }
  let(:gate) { create(:deployment_gate, project: project, pipeline: pipeline, status: :pending) }

  before do
    allow(JenkinsService).to receive(:set_build_description)
  end

  describe "GET /api/v1/deployment_gates/:id" do
    it "returns the gate" do
      get "/api/v1/deployment_gates/#{gate.id}", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)["deployment_gate"]
      expect(body["status"]).to eq("pending")
      expect(body["requires_approval"]).to be(true)
    end

    it "404s for an inaccessible gate" do
      get "/api/v1/deployment_gates/#{create(:deployment_gate).id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/deployment_gates/:id/approve" do
    it "approves a pending gate and passes the pipeline" do
      expect {
        post "/api/v1/deployment_gates/#{gate.id}/approve", headers: headers
      }.to change(Notification, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["deployment_gate"]["status"]).to eq("approved")
      expect(gate.reload).to be_approved
      expect(pipeline.reload.status).to eq("passed")
    end

    it "rejects approving a gate that is not pending" do
      gate.block!("blocked earlier")
      post "/api/v1/deployment_gates/#{gate.id}/approve", headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "forbids QA users" do
      qa = create(:user, role: :qa, team: team)
      qa_project = create(:project, user: qa, team: team)
      qa_gate = create(:deployment_gate, project: qa_project, pipeline: create(:pipeline, project: qa_project))

      post "/api/v1/deployment_gates/#{qa_gate.id}/approve", headers: auth_headers_for(qa)

      expect(response).to have_http_status(:forbidden)
      expect(qa_gate.reload.status).to eq("pending")
    end
  end

  describe "POST /api/v1/deployment_gates/:id/reject" do
    it "blocks a pending gate and blocks the pipeline" do
      post "/api/v1/deployment_gates/#{gate.id}/reject", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["deployment_gate"]["status"]).to eq("blocked")
      expect(gate.reload.reason).to include("Rejected manually")
      expect(pipeline.reload.status).to eq("blocked")
    end
  end
end