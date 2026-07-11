class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :campaign,       null: false, foreign_key: true
      t.string     :external_id,    null: false
      t.string     :name,           null: false
      t.text       :url
      t.text       :image_url
      t.jsonb      :raw_attributes, default: {}
      t.timestamps
    end

    add_index :products, [ :campaign_id, :external_id ], unique: true
    add_index :products, :raw_attributes, using: :gin
    add_index :products, "to_tsvector('simple', name)", using: :gin, name: "idx_products_name_fts"
  end
end
