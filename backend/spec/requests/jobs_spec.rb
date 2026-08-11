require "rails_helper"

RSpec.describe "Jobs API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }
  let(:team) { create(:team) }
  let(:project) { create(:project, user: user, team: team) }
  let(:test_run) { create(:test_run, project: project) }

  describe "GET /api/v1/jobs/:id" do
    it "returns the job with logs, artifacts and execution summary" do
      job = create(
        :job, test_run: test_run, status: :completed,
        worker_id: "sidekiq:123", container_id: "abc123",
        passed_tests: 2, failed_tests: 0, duration_ms: 5000,
        started_at: 10.seconds.ago, finished_at: 5.seconds.ago
      )
      create(:execution_log, job: job, level: "info", message: "Container started")
      create(:artifact, job: job, artifact_type: :video)

      get "/api/v1/jobs/#{job.id}", headers: headers

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)["job"]
      expect(body).to include(
        "status" => "completed",
        "container_id" => "abc123",
        "duration_ms" => 5000,
        "duration_seconds" => be_within(0.1).of(5.0)
      )
      expect(body["summary"]).to include("passed" => 2, "failed" => 0)
      expect(body["logs"].length).to eq(1)
      expect(body["logs"].first["message"]).to eq("Container started")
      expect(body["artifacts"].length).to eq(1)
    end

    it "does not expose jobs from projects the user cannot see" do
      other_user = create(:user)
      other_team = create(:team)
      other_project = create(:project, user: other_user, team: other_team)
      other_run = create(:test_run, project: other_project)
      job = create(:job, test_run: other_run)

      get "/api/v1/jobs/#{job.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      job = create(:job, test_run: test_run)

      get "/api/v1/jobs/#{job.id}"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/jobs/:id/logs" do
    it "returns the execution logs oldest first" do
      job = create(:job, test_run: test_run)
      create(:execution_log, job: job, timestamp: 5.seconds.ago, message: "first")
      create(:execution_log, job: job, timestamp: 1.second.ago, message: "second")

      get "/api/v1/jobs/#{job.id}/logs", headers: headers

      expect(response).to have_http_status(:ok)
      logs = JSON.parse(response.body)["logs"]
      expect(logs.map { |log| log["message"] }).to eq(%w[first second])
      expect(logs.map { |log| log["level"] }).to all(eq("info"))
    end
  end

  describe "GET /api/v1/jobs/:id/artifacts" do
    it "returns the job's artifact metadata" do
      job = create(:job, test_run: test_run)
      create(:artifact, job: job, artifact_type: :screenshot)
      create(:artifact, job: job, artifact_type: :trace)

      get "/api/v1/jobs/#{job.id}/artifacts", headers: headers

      expect(response).to have_http_status(:ok)
      artifacts = JSON.parse(response.body)["artifacts"]
      expect(artifacts.length).to eq(2)
      expect(artifacts.map { |artifact| artifact["artifact_type"] }).to contain_exactly("screenshot", "trace")
    end

    it "includes the full artifact metadata" do
      job = create(:job, test_run: test_run, status: :completed)
      create(:artifact, job: job, artifact_type: :screenshot, file_name: "screenshot.png",
        content_type: "image/png", status: :uploaded, checksum: "a" * 64)

      get "/api/v1/jobs/#{job.id}/artifacts", headers: headers

      artifact = JSON.parse(response.body)["artifacts"].first
      expect(artifact).to include(
        "job_id" => job.id,
        "test_run_id" => test_run.id,
        "artifact_type" => "screenshot",
        "file_name" => "screenshot.png",
        "content_type" => "image/png",
        "status" => "uploaded",
        "storage_backend" => "local"
      )
      expect(artifact["s3_key"]).to be_present
      expect(artifact["checksum"]).to be_present
      expect(artifact["created_at"]).to be_present
    end
  end
end
