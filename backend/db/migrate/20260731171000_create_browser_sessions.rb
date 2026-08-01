class CreateBrowserSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :browser_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :browser_name, null: false, default: "Chrome"
      t.string :status, null: false, default: "running"
      t.datetime :start_time
      t.datetime :end_time
      t.string :container_id

      t.timestamps
    end
  end
end
