require "rails_helper"
require "sidekiq/api"

RSpec.describe "Queue API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }

  describe "GET /api/v1/queue" do
    before do
      # Stub the Sidekiq primitives so the spec does not depend on a live Redis.
      queue = instance_double(Sidekiq::Queue, size: 4)
      workset = instance_double(Sidekiq::WorkSet)
      allow(workset).to receive(:count).and_return(2)
      allow(Sidekiq::Queue).to receive(:new).and_return(queue)
      allow(Sidekiq::WorkSet).to receive(:new).and_return(workset)
    end

    it "returns queue dashboard statistics" do
      create_list(:job, 2, status: :completed)
      create_list(:job, 3, status: :failed)

      get "/api/v1/queue", headers: headers

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)["queue"]
      expect(body).to include(
        "queued_jobs" => 4,
        "running_jobs" => 2,
        "completed_jobs" => 2,
        "failed_jobs" => 3
      )
    end

    it "requires authentication" do
      get "/api/v1/queue"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
