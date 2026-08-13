require "rails_helper"

RSpec.describe "Ci::Jenkins callback API", type: :request do
  let(:project) { create(:project) }
  let!(:pipeline) { create(:pipeline, project: project, status: :running) }
  let!(:build) { create(:build, project: project, pipeline: pipeline, status: :running) }
  let(:secret) { "cb-test-secret" }
  let(:base_headers) { { "Content-Type" => "application/json" } }
  let(:payload) do
    {
      project_id: project.id,
      jenkins_job_name: build.jenkins_job_name,
      jenkins_build_number: build.jenkins_build_number,
      build_status: "SUCCESS"
    }
  end

  before do
    Rails.configuration.executehub[:jenkins][:callback_shared_secret] = secret
  end

  after do
    Rails.configuration.executehub[:jenkins][:callback_shared_secret] = ""
  end

  def post_callback(params, headers: {}, path: "/api/v1/ci/jenkins/callback")
    post path, params: params.to_json, headers: base_headers.merge(headers)
  end

  it "marks the build passed for a successful webhook" do
    post_callback(payload, headers: { "X-Jenkins-Callback-Secret" => secret })

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["build"]["status"]).to eq("passed")
    expect(body["applied"]).to be(true)
    expect(build.reload.status).to eq("passed")
  end

  it "is idempotent — a duplicate webhook is a no-op" do
    post_callback(payload, headers: { "X-Jenkins-Callback-Secret" => secret })
    post_callback(payload, headers: { "X-Jenkins-Callback-Secret" => secret })

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["applied"]).to be(false)
    expect(build.reload.status).to eq("passed")
  end

  it "rejects a request without the secret header" do
    post_callback(payload)
    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a wrong secret" do
    post_callback(payload, headers: { "X-Jenkins-Callback-Secret" => "wrong" })
    expect(response).to have_http_status(:unauthorized)
  end

  it "fails closed when no secret is configured" do
    Rails.configuration.executehub[:jenkins][:callback_shared_secret] = ""
    post_callback(payload, headers: { "X-Jenkins-Callback-Secret" => "" })
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 404 when the build identity is unknown" do
    post_callback(payload.merge(jenkins_build_number: 999_999),
                  headers: { "X-Jenkins-Callback-Secret" => secret })
    expect(response).to have_http_status(:not_found)
  end

  it "cancels the pipeline on ABORTED" do
    post_callback(payload.merge(build_status: "ABORTED"),
                  headers: { "X-Jenkins-Callback-Secret" => secret })
    expect(build.reload.status).to eq("cancelled")
    expect(pipeline.reload.status).to eq("cancelled")
  end

  it "accepts the legacy result field" do
    post_callback(payload.except(:build_status).merge(result: "FAILURE"),
                  headers: { "X-Jenkins-Callback-Secret" => secret })
    expect(build.reload.status).to eq("failed")
  end
end