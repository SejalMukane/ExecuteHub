require "rails_helper"

RSpec.describe TestSuite, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:test_runs) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:total_tests) }

    it "rejects a duplicate name" do
      create(:test_suite, name: "Duplicate Suite")
      expect(build(:test_suite, name: "Duplicate Suite")).not_to be_valid
    end

    it "rejects a non-positive total_tests" do
      suite = build(:test_suite, total_tests: 0)
      expect(suite).not_to be_valid
    end
  end
end
