require "rails_helper"

RSpec.describe TestReport, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:test_run) }
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:total_tests).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:passed_tests).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:failed_tests).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:skipped_tests).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:flaky_tests).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:success_rate).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100) }
    it { is_expected.to validate_presence_of(:generated_at) }
  end
end
