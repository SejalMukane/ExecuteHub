class CreateJobRetries < ActiveRecord::Migration[8.1]
  def change
    create_table :job_retries do |t|
      t.references :job, null: false, foreign_key: true
      t.integer :attempt, null: false
      t.string :reason, null: false
      t.text :error_message
      t.datetime :retried_at, null: false

      t.timestamps
    end

    add_column :jobs, :error_type, :string

    add_index :job_retries, [:job_id, :attempt]
    add_index :jobs, :error_type
  end
end
