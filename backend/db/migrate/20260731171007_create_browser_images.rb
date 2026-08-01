class CreateBrowserImages < ActiveRecord::Migration[8.1]
  def change
    create_table :browser_images do |t|
      t.string :name
      t.string :version
      t.string :tag

      t.timestamps
    end
  end
end
