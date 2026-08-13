require "rails_helper"

RSpec.describe CiApiTokenService do
  let(:project) { create(:project) }

  describe ".create!" do
    it "persists only the digest, never the raw token" do
      record, plaintext = described_class.create!(project: project, name: "Jenkins")

      expect(record).to be_persisted
      expect(record.token_prefix).to eq(plaintext[0, 11])
      expect(record.token_digest).to eq(Digest::SHA256.hexdigest(plaintext))
      expect(CiApiToken.find(record.id).attributes["token_digest"]).not_to eq(plaintext)
    end

    it "uses a project-scoped token" do
      record, = described_class.create!(project: project)
      expect(record.project).to eq(project)
    end
  end

  describe ".authenticate" do
    it "returns the token record for a valid plaintext" do
      record, plaintext = described_class.create!(project: project)
      expect(described_class.authenticate(plaintext)).to eq(record)
    end

    it "returns nil for an unknown token" do
      expect(described_class.authenticate("nope")).to be_nil
    end

    it "returns nil for a revoked token" do
      record, plaintext = described_class.create!(project: project)
      described_class.revoke!(record)
      expect(described_class.authenticate(plaintext)).to be_nil
    end

    it "records last_used_at" do
      _, plaintext = described_class.create!(project: project)
      described_class.authenticate(plaintext)
      expect(CiApiToken.last.last_used_at).to be_present
    end
  end

  describe ".rotate!" do
    it "revokes the old token and issues a new one" do
      old, old_plaintext = described_class.create!(project: project)
      new_record, new_plaintext = described_class.rotate!(old)

      expect(old.reload.revoked?).to be(true)
      expect(new_record).not_to eq(old)
      expect(new_plaintext).not_to eq(old_plaintext)
      expect(described_class.authenticate(old_plaintext)).to be_nil
      expect(described_class.authenticate(new_plaintext)).to eq(new_record)
    end
  end

  describe ".revoke!" do
    it "disables the token immediately" do
      record, plaintext = described_class.create!(project: project)
      described_class.revoke!(record)
      expect(record.reload.revoked?).to be(true)
      expect(described_class.authenticate(plaintext)).to be_nil
    end
  end

  describe ".digest" do
    it "hashes deterministically with SHA-256" do
      expect(described_class.digest("abc")).to eq(Digest::SHA256.hexdigest("abc"))
      expect(described_class.digest("abc")).to eq(described_class.digest("abc"))
    end
  end
end