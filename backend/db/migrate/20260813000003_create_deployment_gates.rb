class CreateDeploymentGates < ActiveRecord::Migration[8.1]
  def change
    create_table :deployment_gates do |t|
      t.bigint :project_id, null: false
      t.bigint :test_run_id
      t.bigint :pipeline_id, null: false
      t.string :status, null: false, default: "pending"
      t.string :reason
      # When true, the gate needs a human to click Approve before it counts
      # as approved. Auto-approved gates skip this.
      t.boolean :requires_approval, null: false, default: true
      t.datetime :decided_at

      t.timestamps
    end

    add_index :deployment_gates, :project_id
    add_index :deployment_gates, :pipeline_id, unique: true
    add_index :deployment_gates, :test_run_id
    add_index :deployment_gates, :status
    add_foreign_key :deployment_gates, :projects
    add_foreign_key :deployment_gates, :test_runs
    add_foreign_key :deployment_gates, :pipelines
  end
end