require "rails_helper"

RSpec.describe "Analytics API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }
  let(:team) { create(:team) }
  let(:project) { create(:project, user: user, team: team) }

  def seed_run(passed:, failed:)
    run = create(:test_run, project: project, status: :completed)
    job = create(:job, test_run: run, status: :completed)
    passed.times { create(:test_result, job: job, test_run: run, status: :passed) }
    failed.times { create(:test_result, job: job, test_run: run, status: :failed) }
    run
  end

  describe "GET /api/v1/analytics" do
    it "returns the global analytics overview and history" do
      seed_run(passed: 90, failed: 10)

      get "/api/v1/analytics", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["overview"]["tests_executed"]).to eq(100)
      expect(body["overview"]["tests_passed"]).to eq(90)
      expect(body["overview"]["tests_failed"]).to eq(10)
      expect(body["overview"]["success_rate"]).to eq(90.0)
      expect(body["history"]["success_rate_over_time"]).to be_an(Array)
      expect(body["history"]["most_failing_tests"]).to be_an(Array)
      expect(body["history"]["most_failing_suites"]).to be_an(Array)
    end

    it "requires authentication" do
      get "/api/v1/analytics"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/projects/:project_id/analytics" do
    it "returns project-scoped analytics" do
      seed_run(passed: 50, failed: 50)

      get "/api/v1/projects/#{project.id}/analytics?days=7", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["overview"]["total_test_runs"]).to eq(1)
      expect(body["overview"]["success_rate"]).to eq(50.0)
    end

    it "clamps the days parameter to the supported range" do
      seed_run(passed: 1, failed: 0)

      get "/api/v1/projects/#{project.id}/analytics?days=9999", headers: headers

      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for a project the user cannot access" do
      get "/api/v1/projects/#{create(:project).id}/analytics", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
