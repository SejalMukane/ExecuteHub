require "rails_helper"

RSpec.describe "Artifacts API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }
  let(:team) { create(:team) }
  let(:project) { create(:project, user: user, team: team) }
  let(:test_run) { create(:test_run, project: project) }
  let(:job) { create(:job, test_run: test_run) }

  def local_artifact(type: :screenshot, content: "PNGDATA", file_name: "screenshot.png")
    dir = ArtifactStore.prepare(job)
    path = dir.join("artifacts", file_name)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, content)
    create(
      :artifact, job: job, artifact_type: type,
      path: ArtifactStore.relative(path), file_name: file_name,
      size: File.size(path)
    )
  end

  describe "GET /api/v1/artifacts" do
    it "lists the caller's recent artifacts newest first" do
      old_artifact = create(:artifact, job: job, artifact_type: :screenshot, created_at: 2.days.ago)
      new_artifact = create(:artifact, job: job, artifact_type: :video, created_at: 1.hour.ago)

      get "/api/v1/artifacts", headers: headers

      expect(response).to have_http_status(:ok)
      artifacts = JSON.parse(response.body)["artifacts"]
      expect(artifacts.map { |a| a["id"] }).to eq([new_artifact.id, old_artifact.id])
      expect(artifacts.first).to include("artifact_type", "file_name", "status", "storage_backend")
    end

    it "excludes artifacts from projects the user cannot see" do
      other = create(:project, user: create(:user), team: create(:team))
      create(:artifact, job: create(:job, test_run: create(:test_run, project: other)), artifact_type: :screenshot)

      get "/api/v1/artifacts", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["artifacts"]).to be_empty
    end

    it "requires authentication" do
      get "/api/v1/artifacts"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/artifacts/:id" do
    it "returns artifact metadata without exposing AWS details" do
      artifact = create(:artifact, job: job, artifact_type: :video, status: :uploaded)

      get "/api/v1/artifacts/#{artifact.id}", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)["artifact"]
      expect(body).to include(
        "id" => artifact.id,
        "artifact_type" => "video",
        "status" => "uploaded",
        "storage_backend" => "local"
      )
      expect(body["file_size"]).to eq(1024)
    end

    it "does not expose artifacts from other projects" do
      other_user = create(:user)
      other_team = create(:team)
      other_project = create(:project, user: other_user, team: other_team)
      other_run = create(:test_run, project: other_project)
      other_job = create(:job, test_run: other_run)
      artifact = create(:artifact, job: other_job, artifact_type: :video)

      get "/api/v1/artifacts/#{artifact.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      artifact = create(:artifact, job: job, artifact_type: :video)
      get "/api/v1/artifacts/#{artifact.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/artifacts/:id/url" do
    it "returns a signed URL with a 15-minute default expiry" do
      artifact = create(:artifact, job: job, artifact_type: :screenshot)

      expect(StorageService.adapter).to receive(:signed_url).with(artifact.s3_key, expires_in: 900)
        .and_return("https://s3.example.com/signed")

      get "/api/v1/artifacts/#{artifact.id}/url", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["url"]).to eq("https://s3.example.com/signed")
      expect(body["expires_in"]).to eq(900)
      expect(body["storage_backend"]).to eq("local")
    end
  end

  describe "GET /api/v1/artifacts/:id/file" do
    it "streams the artifact bytes with the correct content type" do
      artifact = local_artifact(content: "PNGDATA")

      get "/api/v1/artifacts/#{artifact.id}/file", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("PNGDATA")
      expect(response.content_type).to include("image/png")
    end

    it "redirects to a signed URL when S3 is configured" do
      artifact = create(:artifact, job: job, artifact_type: :video)
      allow(StorageService).to receive(:adapter).and_return(S3StorageService)
      expect(S3StorageService).to receive(:signed_url).with(artifact.s3_key).and_return("https://s3.example.com/video")

      get "/api/v1/artifacts/#{artifact.id}/file", headers: headers

      expect(response).to have_http_status(:redirect)
      expect(response.location).to eq("https://s3.example.com/video")
    end
  end

  describe "DELETE /api/v1/artifacts/:id" do
    it "deletes the remote object and the database record" do
      artifact = create(:artifact, job: job, artifact_type: :trace, status: :uploaded)

      expect(StorageService.adapter).to receive(:delete).with(artifact.s3_key)

      delete "/api/v1/artifacts/#{artifact.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Artifact.exists?(artifact.id)).to be(false)
    end

    it "still deletes the record when the remote delete fails" do
      artifact = create(:artifact, job: job, artifact_type: :trace, status: :uploaded)
      expect(StorageService.adapter).to receive(:delete).and_raise(S3StorageService::S3Error, "down")

      delete "/api/v1/artifacts/#{artifact.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Artifact.exists?(artifact.id)).to be(false)
    end

    it "does not allow deleting artifacts from other projects" do
      other_user = create(:user)
      other_project = create(:project, user: other_user, team: create(:team))
      other_artifact = create(:artifact, job: create(:job, test_run: create(:test_run, project: other_project)))

      delete "/api/v1/artifacts/#{other_artifact.id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(Artifact.exists?(other_artifact.id)).to be(true)
    end
  end

  describe "POST /api/v1/artifacts/:id/retry" do
    it "re-enqueues the upload for a failed artifact" do
      artifact = create(:artifact, job: job, artifact_type: :log, status: :failed)

      expect(ArtifactUploadJob).to receive(:perform_async).with(artifact.id)

      post "/api/v1/artifacts/#{artifact.id}/retry", headers: headers

      expect(response).to have_http_status(:ok)
      expect(artifact.reload.status).to eq("uploading")
    end

    it "does not re-upload artifacts that already succeeded" do
      artifact = create(:artifact, job: job, artifact_type: :log, status: :uploaded)

      expect(ArtifactUploadJob).not_to receive(:perform_async)

      post "/api/v1/artifacts/#{artifact.id}/retry", headers: headers

      expect(response).to have_http_status(:ok)
      expect(artifact.reload.status).to eq("uploaded")
    end
  end
end
