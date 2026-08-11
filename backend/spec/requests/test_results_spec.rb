require "rails_helper"

RSpec.describe "TestResults API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }
  let(:team) { create(:team) }
  let(:project) { create(:project, user: user, team: team) }
  let(:test_run) { create(:test_run, project: project, status: :completed) }
  let(:job) { create(:job, test_run: test_run, status: :completed, worker_id: "Worker-03") }

  describe "GET /api/v1/test_results/:id" do
    it "returns the failure debugging detail with artifacts and logs" do
      result = create(:test_result, job: job, test_run: test_run, status: :failed,
        test_name: "Login Test", browser: "Chrome", error_message: "Expected: Dashboard",
        stack_trace: "Error: Expected: Dashboard\n    at login.spec.ts:12", retry_count: 2,
        duration_ms: 12_400)
      create(:execution_log, job: job, level: "error", message: "test failed")
      create(:artifact, job: job, artifact_type: :screenshot, status: :uploaded)

      get "/api/v1/test_results/#{result.id}", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)["test_result"]
      expect(body["test_name"]).to eq("Login Test")
      expect(body["status"]).to eq("failed")
      expect(body["browser"]).to eq("Chrome")
      expect(body["worker"]).to eq("Worker-03")
      expect(body["retry_count"]).to eq(2)
      expect(body["duration_ms"]).to eq(12_400)
      expect(body["error_message"]).to eq("Expected: Dashboard")
      expect(body["stack_trace"]).to include("login.spec.ts:12")
      expect(body["artifacts"].map { |a| a["artifact_type"] }).to include("screenshot")
      expect(body["logs"].length).to eq(1)
    end

    it "does not expose results from other projects" do
      other = create(:project, user: create(:user), team: create(:team))
      other_result = create(:test_result,
        job: create(:job, test_run: create(:test_run, project: other)), test_run: other.test_runs.first)

      get "/api/v1/test_results/#{other_result.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      result = create(:test_result, job: job, test_run: test_run)
      get "/api/v1/test_results/#{result.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
