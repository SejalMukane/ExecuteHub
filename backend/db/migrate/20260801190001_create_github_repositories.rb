class CreateGithubRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :github_repositories do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.references :github_integration, null: false, foreign_key: true
      t.bigint :github_repo_id, null: false
      t.string :full_name, null: false
      t.string :html_url
      t.string :clone_url
      t.string :ssh_url
      t.string :default_branch
      t.text :description
      t.boolean :private, default: false, null: false

      t.timestamps
    end
    add_index :github_repositories, :github_repo_id, unique: true
  end
end
