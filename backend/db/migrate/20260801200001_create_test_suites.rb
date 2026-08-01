class CreateTestSuites < ActiveRecord::Migration[8.1]
  def change
    create_table :test_suites do |t|
      t.string :name, null: false
      t.text :description
      t.integer :total_tests, null: false, default: 0
      t.timestamps
    end

    add_index :test_suites, :name, unique: true
    add_reference :test_runs, :test_suite, foreign_key: true
  end
end
