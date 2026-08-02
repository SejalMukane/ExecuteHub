require "rails_helper"

RSpec.describe JobsChannel, type: :channel do
  let(:user) { create(:user) }

  before do
    stub_connection current_user: user
  end

  it "subscribes to the shared jobs stream" do
    subscribe

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("jobs")
  end

  it "additionally streams a specific job when requested" do
    subscribe job_id: 123

    expect(subscription).to have_stream_from("jobs")
    expect(subscription).to have_stream_from("job_123")
  end
end
