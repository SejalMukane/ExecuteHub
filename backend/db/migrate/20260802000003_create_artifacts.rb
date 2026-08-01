class CreateArtifacts < ActiveRecord::Migration[8.1]
  def change
    create_table :artifacts do |t|
      t.references :job, null: false, foreign_key: true
      t.string :artifact_type, null: false
      t.string :path, null: false
      t.bigint :size, null: false, default: 0

      t.timestamps
    end

    add_index :artifacts, [:job_id, :artifact_type]
  end
end
