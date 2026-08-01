require "rails_helper"

RSpec.describe "Artifacts API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }
  let(:team) { create(:team) }
  let(:project) { create(:project, user: user, team: team) }
  let(:test_run) { create(:test_run, project: project) }

  describe "GET /api/v1/artifacts/:id/file" do
    it "streams the artifact bytes with the correct content type" do
      job = create(:job, test_run: test_run)
      dir = ArtifactStore.prepare(job)
      path = dir.join("artifacts", "screenshot.png")
      FileUtils.mkdir_p(path.dirname)
      File.write(path, "PNGDATA")
      artifact = create(
        :artifact, job: job, artifact_type: :screenshot,
        path: ArtifactStore.relative(path), size: File.size(path)
      )

      get "/api/v1/artifacts/#{artifact.id}/file", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("PNGDATA")
      expect(response.content_type).to include("image/png")
    ensure
      FileUtils.rm_rf(dir) if dir
    end

    it "does not expose artifacts from other projects" do
      other_user = create(:user)
      other_team = create(:team)
      other_project = create(:project, user: other_user, team: other_team)
      other_run = create(:test_run, project: other_project)
      job = create(:job, test_run: other_run)
      artifact = create(:artifact, job: job, artifact_type: :video)

      get "/api/v1/artifacts/#{artifact.id}/file", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      job = create(:job, test_run: test_run)
      artifact = create(:artifact, job: job, artifact_type: :video)

      get "/api/v1/artifacts/#{artifact.id}/file"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
