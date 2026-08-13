require "rails_helper"

RSpec.describe CiApiToken, type: :model do
  subject(:token) { create(:ci_api_token) }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:token_digest) }
  it { is_expected.to validate_uniqueness_of(:token_digest) }
  it { is_expected.to validate_presence_of(:token_prefix) }

  describe "#revoked?" do
    it "is false by default" do
      expect(token.revoked?).to be(false)
    end

    it "is true after revocation" do
      token.update!(revoked_at: Time.current)
      expect(token.revoked?).to be(true)
    end
  end

  describe ".active" do
    it "excludes revoked tokens" do
      active = create(:ci_api_token)
      revoked = create(:ci_api_token, revoked_at: Time.current)
      expect(described_class.active).to include(active)
      expect(described_class.active).not_to include(revoked)
    end
  end
end