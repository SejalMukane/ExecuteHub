require "rails_helper"

RSpec.describe "Notifications API", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, role: :developer, team: team) }
  let(:headers) { auth_headers_for(user) }
  let(:project) { create(:project, user: user, team: team) }

  describe "GET /api/v1/notifications" do
    it "lists the user's notifications newest first" do
      older = create(:notification, project: project, created_at: 2.days.ago)
      newer = create(:notification, project: project, created_at: 1.day.ago)
      create(:notification, project: create(:project))

      get "/api/v1/notifications", headers: headers

      expect(response).to have_http_status(:ok)
      notifications = JSON.parse(response.body)["notifications"]
      expect(notifications.map { |n| n["id"] }).to eq([newer.id, older.id])
    end

    it "filters by unread" do
      create(:notification, project: project, read: false)
      create(:notification, project: project, read: true)

      get "/api/v1/notifications?unread=true", headers: headers

      notifications = JSON.parse(response.body)["notifications"]
      expect(notifications.length).to eq(1)
      expect(notifications.first["read"]).to be(false)
    end

    it "filters by project" do
      mine = create(:notification, project: project)
      other = create(:notification, project: create(:project))

      get "/api/v1/notifications?project_id=#{project.id}", headers: headers

      notifications = JSON.parse(response.body)["notifications"]
      expect(notifications.map { |n| n["id"] }).to eq([mine.id])
      expect(notifications.map { |n| n["id"] }).not_to include(other.id)
    end

    it "requires authentication" do
      get "/api/v1/notifications"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/notifications/:id" do
    it "returns a single notification" do
      notification = create(:notification, project: project, title: "Hello")

      get "/api/v1/notifications/#{notification.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["notification"]["title"]).to eq("Hello")
    end

    it "404s for a notification outside the user's visibility" do
      get "/api/v1/notifications/#{create(:notification).id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/notifications/:id/read" do
    it "marks a notification as read" do
      notification = create(:notification, project: project, read: false)

      patch "/api/v1/notifications/#{notification.id}/read", headers: headers

      expect(response).to have_http_status(:ok)
      expect(notification.reload.read?).to be(true)
    end
  end

  describe "POST /api/v1/notifications/read_all" do
    it "marks all visible unread notifications as read" do
      create_list(:notification, 2, project: project)

      post "/api/v1/notifications/read_all", headers: headers

      expect(response).to have_http_status(:ok)
      expect(project.notifications.unread.count).to eq(0)
    end
  end
end