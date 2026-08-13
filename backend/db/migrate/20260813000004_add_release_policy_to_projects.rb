class AddReleasePolicyToProjects < ActiveRecord::Migration[8.1]
  def change
    # Per-project release-gating configuration consumed by ReleaseGateService.
    # Example: { "minimum_success_rate" => 95, "required_suites" => ["smoke", "regression"] }
    add_column :projects, :release_policy, :jsonb, null: false, default: {}
  end
end