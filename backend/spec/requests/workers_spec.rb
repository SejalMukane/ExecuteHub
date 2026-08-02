require "rails_helper"

RSpec.describe "Worker Pool API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }

  describe "GET /api/v1/workers" do
    it "returns the pool summary and every worker" do
      create(:worker_heartbeat, worker_name: "Worker-01", status: :idle,
                                cpu_usage: 12.5, memory_usage: 20.0, execution_count: 3)
      create(:worker_heartbeat, worker_name: "Worker-02", status: :busy,
                                cpu_usage: 70.0, memory_usage: 50.0, execution_count: 7)
      create(:worker_heartbeat, worker_name: "Worker-03", status: :offline,
                                last_seen_at: 1.minute.ago)

      get "/api/v1/workers", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body["counts"]).to include("total" => 3, "idle" => 1, "busy" => 1, "offline" => 1)
      expect(body["workers"].map { |w| w["worker_name"] }).to eq(%w[Worker-01 Worker-02 Worker-03])
    end

    it "includes the current job of a busy worker" do
      job = create(:job, status: :running, container_id: "abc123")
      create(:worker_heartbeat, worker_name: "Worker-01", status: :busy, current_job: job)

      get "/api/v1/workers", headers: headers

      worker = JSON.parse(response.body)["workers"].first
      expect(worker["current_job"]["id"]).to eq(job.id)
      expect(worker["current_job"]["status"]).to eq("running")
      expect(worker["current_job"]["container_id"]).to eq("abc123")
    end

    it "requires authentication" do
      get "/api/v1/workers"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/workers/:id" do
    it "returns a single worker" do
      worker = create(:worker_heartbeat, worker_name: "Worker-01", status: :idle,
                                         cpu_usage: 12.5, memory_usage: 20.0, execution_count: 3)

      get "/api/v1/workers/#{worker.id}", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)["worker"]
      expect(body["worker_name"]).to eq("Worker-01")
      expect(body["status"]).to eq("idle")
      expect(body["current_job"]).to be_nil
    end

    it "returns 404 for an unknown worker" do
      get "/api/v1/workers/999_999", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
