require "rails_helper"

RSpec.describe DashboardChannel, type: :channel do
  let(:user) { create(:user) }

  before do
    stub_connection current_user: user
  end

  it "subscribes to the shared dashboard stream" do
    subscribe

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("dashboard")
  end
end
