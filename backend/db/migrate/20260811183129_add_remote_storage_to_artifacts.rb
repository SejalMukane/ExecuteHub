# Week 7 — expands Artifact into a full remote-storage record. Local filesystem
# paths are retained (path) so failed S3 uploads can be retried and local
# development works without AWS; s3_key / checksum / content_type describe the
# object stored in S3 (or the local store when running without AWS).
class AddRemoteStorageToArtifacts < ActiveRecord::Migration[8.1]
  def up
    add_column :artifacts, :test_run_id, :bigint
    add_column :artifacts, :file_name, :string
    add_column :artifacts, :s3_key, :string
    add_column :artifacts, :content_type, :string
    add_column :artifacts, :checksum, :string
    add_column :artifacts, :status, :string, default: "pending", null: false

    add_index :artifacts, :test_run_id
    add_index :artifacts, :status
    add_index :artifacts, :created_at
    add_index :artifacts, :s3_key, unique: true

    # Backfill test_run_id from each artifact's job. Safe for existing rows.
    execute(<<~SQL)
      UPDATE artifacts
      SET test_run_id = jobs.test_run_id
      FROM jobs
      WHERE artifacts.job_id = jobs.id
        AND artifacts.test_run_id IS NULL
    SQL

    add_foreign_key :artifacts, :test_runs
  end

  def down
    remove_foreign_key :artifacts, :test_runs
    remove_index :artifacts, :s3_key
    remove_index :artifacts, :created_at
    remove_index :artifacts, :status
    remove_index :artifacts, :test_run_id
    remove_column :artifacts, :status
    remove_column :artifacts, :checksum
    remove_column :artifacts, :content_type
    remove_column :artifacts, :s3_key
    remove_column :artifacts, :file_name
    remove_column :artifacts, :test_run_id
  end
end
