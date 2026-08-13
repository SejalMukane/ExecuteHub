require "rails_helper"

RSpec.describe "CiTokens API", type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, role: :developer, team: team) }
  let(:headers) { auth_headers_for(user) }
  let(:project) { create(:project, user: user, team: team) }

  describe "POST /api/v1/ci_tokens" do
    it "creates a token and returns the plaintext once" do
      expect {
        post "/api/v1/ci_tokens", params: { project_id: project.id, name: "Jenkins" },
             headers: headers, as: :json
      }.to change(CiApiToken, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["token"]).to start_with("eh_")
      expect(body["ci_token"]["token_prefix"]).to eq(body["token"][0, 11])
      # Never echo the raw token or the digest in metadata.
      expect(body["ci_token"].keys).not_to include("token_digest")
      expect(body["ci_token"].keys).not_to include("token")
    end

    it "requires authentication" do
      post "/api/v1/ci_tokens", params: { project_id: project.id, name: "Jenkins" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "forbids QA users" do
      qa = create(:user, role: :qa, team: team)
      qa_project = create(:project, user: qa, team: team)
      post "/api/v1/ci_tokens", params: { project_id: qa_project.id }, headers: auth_headers_for(qa), as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "404s for a project outside the user's visibility" do
      other = create(:project)
      post "/api/v1/ci_tokens", params: { project_id: other.id }, headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/ci_tokens" do
    it "lists token metadata without secrets" do
      token = create(:ci_api_token, project: project, name: "Jenkins")

      get "/api/v1/ci_tokens?project_id=#{project.id}", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)["ci_tokens"]
      expect(body.length).to eq(1)
      expect(body.first["id"]).to eq(token.id)
      expect(body.first["token_prefix"]).to eq(token.token_prefix)
    end
  end

  describe "DELETE /api/v1/ci_tokens/:id" do
    it "revokes the token" do
      token = create(:ci_api_token, project: project)

      delete "/api/v1/ci_tokens/#{token.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(token.reload.revoked?).to be(true)
    end
  end

  describe "POST /api/v1/ci_tokens/:id/rotate" do
    it "revokes the old token and returns a fresh plaintext" do
      token = create(:ci_api_token, project: project)
      original_digest = token.token_digest

      post "/api/v1/ci_tokens/#{token.id}/rotate", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["token"]).to start_with("eh_")
      expect(token.reload.revoked?).to be(true)
      expect(body["ci_token"]["id"]).not_to eq(token.id)
      expect(body["ci_token"]["token_digest"]).not_to eq(original_digest)
    end
  end
end