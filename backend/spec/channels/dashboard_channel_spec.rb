require "rails_helper"

RSpec.describe DashboardChannel, type: :channel do
  let(:user) { create(:user) }

  before do
    stub_connection current_user: user
  end

  it "subscribes to the shared dashboard stream and sends an initial snapshot" do
    subscribe

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("dashboard")
    expect(transmissions).to include(hash_including(type: :metrics_updated))
  end
end
