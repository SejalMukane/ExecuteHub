class AddExecutionFieldsToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :container_id, :string
    add_column :jobs, :passed_tests, :integer, default: 0, null: false
    add_column :jobs, :failed_tests, :integer, default: 0, null: false
    add_column :jobs, :duration_ms, :integer
    add_column :jobs, :error_message, :text

    add_index :jobs, :container_id
  end
end
