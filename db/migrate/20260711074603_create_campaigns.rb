class CreateCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :campaigns do |t|
      t.references :user,          null: false, foreign_key: true
      t.string     :name,          null: false
      t.string     :keyword
      t.string     :target_source, null: false
      t.string     :frequency,     default: "daily"
      t.string     :status,        default: "active"
      t.datetime   :last_crawled_at
      t.timestamps
    end

    add_index :campaigns, :status
  end
end
