require "rails_helper"

RSpec.describe DeploymentGate, type: :model do
  subject(:gate) { create(:deployment_gate) }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:pipeline) }
  it { is_expected.to belong_to(:test_run).optional }

  describe "enums" do
    it "defines the expected statuses" do
      expect(described_class.statuses.keys).to match_array(%w[pending approved blocked expired])
    end
  end

  describe "#approve!" do
    it "marks the gate approved and stamps decided_at" do
      gate.approve!
      expect(gate).to be_approved
      expect(gate.decided_at).to be_present
      expect(gate.reason).to be_nil
    end
  end

  describe "#block!" do
    it "marks the gate blocked with a reason" do
      gate.block!("Critical checkout test failed.")
      expect(gate).to be_blocked
      expect(gate.reason).to eq("Critical checkout test failed.")
      expect(gate.decided_at).to be_present
    end
  end
end