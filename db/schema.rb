# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_11_074730) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "campaigns", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "frequency", default: "daily"
    t.string "keyword"
    t.datetime "last_crawled_at"
    t.string "name", null: false
    t.string "status", default: "active"
    t.string "target_source", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["status"], name: "index_campaigns_on_status"
    t.index ["user_id"], name: "index_campaigns_on_user_id"
  end

  create_table "price_histories", force: :cascade do |t|
    t.decimal "discount_rate", precision: 5, scale: 2
    t.decimal "price", precision: 15, scale: 2, null: false
    t.bigint "product_id", null: false
    t.datetime "recorded_at", null: false
    t.index ["product_id", "recorded_at"], name: "index_price_histories_on_product_id_and_recorded_at"
    t.index ["product_id"], name: "index_price_histories_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.text "image_url"
    t.string "name", null: false
    t.jsonb "raw_attributes", default: {}
    t.datetime "updated_at", null: false
    t.text "url"
    t.index "to_tsvector('simple'::regconfig, (name)::text)", name: "idx_products_name_fts", using: :gin
    t.index ["campaign_id", "external_id"], name: "index_products_on_campaign_id_and_external_id", unique: true
    t.index ["campaign_id"], name: "index_products_on_campaign_id"
    t.index ["raw_attributes"], name: "index_products_on_raw_attributes", using: :gin
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "campaigns", "users"
  add_foreign_key "price_histories", "products"
  add_foreign_key "products", "campaigns"
end
