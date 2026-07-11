class CreatePriceHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :price_histories do |t|
      t.references :product,       null: false, foreign_key: true
      t.decimal    :price,         precision: 15, scale: 2, null: false
      t.decimal    :discount_rate, precision: 5,  scale: 2
      t.datetime   :recorded_at,   null: false
    end

    add_index :price_histories, [:product_id, :recorded_at]
  end
end
