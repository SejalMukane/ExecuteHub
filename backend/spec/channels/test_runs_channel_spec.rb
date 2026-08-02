require "rails_helper"

RSpec.describe TestRunsChannel, type: :channel do
  let(:user) { create(:user) }
  let(:test_run) { create(:test_run) }

  before do
    stub_connection current_user: user
  end

  it "streams the given test run's events" do
    subscribe id: test_run.id

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("test_run_#{test_run.id}")
  end
end
