require "rails_helper"

RSpec.describe "TestRuns API", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, role: :developer, team: team) }
  let(:headers) { auth_headers_for(user) }
  let(:project) { create(:project, user: user, team: team) }

  describe "POST /api/v1/projects/:project_id/test_runs" do
    let(:valid_payload) do
      { branch: "feature/auth", commit_sha: "a" * 40, total_tests: 100 }
    end

    it "creates a test run and schedules its jobs" do
      expect {
        post "/api/v1/projects/#{project.id}/test_runs",
             params: valid_payload, headers: headers, as: :json
      }.to change(TestRun, :count).by(1)
       .and change { project.test_runs.count }.by(1)

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      run = body["test_run"]

      expect(run["project_id"]).to eq(project.id)
      expect(run["branch"]).to eq("feature/auth")
      expect(run["commit_sha"]).to eq("a" * 40)
      expect(run["status"]).to eq("queued")
      expect(run["total_jobs"]).to eq(5)
      expect(run["jobs"].size).to eq(5)
      expect(run["jobs"].first["chunk_number"]).to eq(1)
      expect(run["jobs"].first["test_count"]).to eq(20)
    end

    it "requires authentication" do
      post "/api/v1/projects/#{project.id}/test_runs",
           params: valid_payload, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a project the user cannot see" do
      other = create(:project)

      post "/api/v1/projects/#{other.id}/test_runs",
           params: valid_payload, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 for an invalid payload" do
      post "/api/v1/projects/#{project.id}/test_runs",
           params: { branch: "main" }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "forbids QA users" do
      qa = create(:user, role: :qa, team: team)
      qa_headers = auth_headers_for(qa)
      qa_project = create(:project, user: qa, team: team)

      post "/api/v1/projects/#{qa_project.id}/test_runs",
           params: valid_payload, headers: qa_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/test_runs/suites" do
    it "lists test suites" do
      suite = create(:test_suite, name: "Smoke Tests", total_tests: 120)

      get "/api/v1/test_runs/suites", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)["test_suites"]
      expect(body.map { |s| s["id"] }).to include(suite.id)
      expect(body.find { |s| s["id"] == suite.id }["total_tests"]).to eq(120)
    end

    it "requires authentication" do
      get "/api/v1/test_runs/suites"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST with a test suite" do
    let(:suite) { create(:test_suite, name: "Regression", total_tests: 40) }

    it "uses the suite's test count when total_tests is omitted" do
      post "/api/v1/projects/#{project.id}/test_runs",
           params: { branch: "main", test_suite_id: suite.id }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      run = JSON.parse(response.body)["test_run"]
      expect(run["total_tests"]).to eq(40)
      expect(run["total_jobs"]).to eq(2)
      expect(run["test_suite"]["id"]).to eq(suite.id)
    end

    it "lets an explicit total_tests override the suite" do
      post "/api/v1/projects/#{project.id}/test_runs",
           params: { branch: "main", test_suite_id: suite.id, total_tests: 100 },
           headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["test_run"]["total_tests"]).to eq(100)
    end

    it "returns 422 for an unknown suite" do
      post "/api/v1/projects/#{project.id}/test_runs",
           params: { branch: "main", test_suite_id: 999_999 }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/v1/test_runs" do
    it "lists the user's test runs newest first" do
      older = create(:test_run, project: project, created_at: 2.days.ago)
      newer = create(:test_run, project: project, created_at: 1.day.ago)

      get "/api/v1/test_runs", headers: headers

      expect(response).to have_http_status(:ok)
      runs = JSON.parse(response.body)["test_runs"]
      expect(runs.map { |r| r["id"] }).to eq([newer.id, older.id])
    end

    it "excludes test runs from other users' projects" do
      create(:test_run, project: create(:project))

      get "/api/v1/test_runs", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["test_runs"]).to be_empty
    end

    it "requires authentication" do
      get "/api/v1/test_runs"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/test_runs/:id" do
    it "returns the run with its jobs and progress" do
      run = create(:test_run, project: project, total_tests: 40)
      create(:job, test_run: run, chunk_number: 1, status: :completed)
      create(:job, test_run: run, chunk_number: 2, status: :queued)
      TestRunProgressUpdater.call(run)

      get "/api/v1/test_runs/#{run.id}", headers: headers

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)["test_run"]
      expect(body["id"]).to eq(run.id)
      expect(body["status"]).to eq("running")
      expect(body["total_jobs"]).to eq(2)
      expect(body["completed_jobs"]).to eq(1)
      expect(body["progress_percentage"]).to eq(50.0)
      expect(body["jobs"].size).to eq(2)
      expect(body["jobs"].map { |j| j["id"] }).to eq(run.jobs.order(:chunk_number).pluck(:id))
    end

    it "returns 404 for a run the user cannot access" do
      run = create(:test_run, project: create(:project))

      get "/api/v1/test_runs/#{run.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      get "/api/v1/test_runs/1"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/test_runs/:id/progress" do
    it "returns the live progress snapshot" do
      run = create(:test_run, project: project, total_tests: 40)
      create(:job, test_run: run, status: :running)
      create(:job, test_run: run, status: :queued)
      create(:job, test_run: run, status: :completed)
      TestRunProgressUpdater.call(run)

      get "/api/v1/test_runs/#{run.id}/progress", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)["test_run"]
      expect(body["id"]).to eq(run.id)
      expect(body["total_jobs"]).to eq(3)
      expect(body["queued_jobs"]).to eq(1)
      expect(body["running_jobs"]).to eq(1)
      expect(body["completed_jobs"]).to eq(1)
      expect(body["progress_percentage"]).to eq(33.3)
    end

    it "returns 404 for a run the user cannot access" do
      run = create(:test_run, project: create(:project))

      get "/api/v1/test_runs/#{run.id}/progress", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      get "/api/v1/test_runs/1/progress"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/test_runs/:id/report" do
    it "returns the aggregated report and every test result" do
      run = create(:test_run, project: project, total_tests: 100, status: :completed)
      job = create(:job, test_run: run, status: :completed)
      create(:test_result, job: job, test_run: run, status: :passed, test_name: "login ok")
      create(:test_result, job: job, test_run: run, status: :failed, test_name: "checkout fails")
      TestReportGenerator.call(run)

      get "/api/v1/test_runs/#{run.id}/report", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      report = body["test_report"]
      expect(report["total_tests"]).to eq(2)
      expect(report["passed_tests"]).to eq(1)
      expect(report["failed_tests"]).to eq(1)
      expect(report["success_rate"]).to eq(50.0)
      expect(body["test_results"].map { |r| r["status"] }).to contain_exactly("passed", "failed")
      expect(body["test_results"].first["worker"]).to eq(job.worker_id)
    end

    it "returns a nil report before aggregation completes" do
      run = create(:test_run, project: project, status: :running)

      get "/api/v1/test_runs/#{run.id}/report", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["test_report"]).to be_nil
    end

    it "returns 404 for a run the user cannot access" do
      run = create(:test_run, project: create(:project))
      get "/api/v1/test_runs/#{run.id}/report", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/test_runs/:id/results" do
    it "returns the run's individual test outcomes" do
      run = create(:test_run, project: project, status: :completed)
      job = create(:job, test_run: run, status: :completed)
      create(:test_result, job: job, test_run: run, status: :failed, test_name: "broken test")

      get "/api/v1/test_runs/#{run.id}/results", headers: headers

      expect(response).to have_http_status(:ok)
      results = JSON.parse(response.body)["test_results"]
      expect(results.length).to eq(1)
      expect(results.first["test_name"]).to eq("broken test")
      expect(results.first["status"]).to eq("failed")
    end
  end

  describe "GET /api/v1/test_runs/:id/analytics" do
    it "returns run-scoped analytics" do
      run = create(:test_run, project: project, status: :completed)
      job = create(:job, test_run: run, status: :completed)
      create(:test_result, job: job, test_run: run, status: :passed)

      get "/api/v1/test_runs/#{run.id}/analytics", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["overview"]["tests_executed"]).to eq(1)
      expect(body["overview"]["success_rate"]).to eq(100.0)
    end
  end
end
