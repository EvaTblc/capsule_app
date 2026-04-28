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

ActiveRecord::Schema[8.1].define(version: 2026_04_28_135534) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "board_game_details", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration"
    t.integer "max_players"
    t.integer "min_players"
    t.string "publisher"
    t.datetime "updated_at", null: false
  end

  create_table "book_details", force: :cascade do |t|
    t.string "author"
    t.datetime "created_at", null: false
    t.string "genre"
    t.string "isbn"
    t.integer "pages"
    t.string "publisher"
    t.datetime "updated_at", null: false
  end

  create_table "collections", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "invite_token"
    t.boolean "public"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "figurine_details", force: :cascade do |t|
    t.string "brand"
    t.datetime "created_at", null: false
    t.boolean "limited_edition"
    t.string "material"
    t.string "scale"
    t.datetime "updated_at", null: false
  end

  create_table "items", force: :cascade do |t|
    t.date "acquired_at"
    t.string "barcode"
    t.bigint "collection_id", null: false
    t.string "condition"
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "item_detailable_id", null: false
    t.string "item_detailable_type", null: false
    t.string "item_type"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["collection_id"], name: "index_items_on_collection_id"
    t.index ["item_detailable_type", "item_detailable_id"], name: "index_items_on_item_detailable"
  end

  create_table "movie_details", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "director"
    t.string "format"
    t.string "studio"
    t.datetime "updated_at", null: false
    t.integer "year"
  end

  create_table "music_details", force: :cascade do |t|
    t.string "album"
    t.string "artist"
    t.datetime "created_at", null: false
    t.string "format"
    t.string "label"
    t.datetime "updated_at", null: false
    t.integer "year"
  end

  create_table "tcg_details", force: :cascade do |t|
    t.string "card_number"
    t.string "card_set"
    t.string "condition"
    t.datetime "created_at", null: false
    t.string "game"
    t.string "rarity"
    t.datetime "updated_at", null: false
  end

  create_table "user_collections", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.datetime "created_at", null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["collection_id"], name: "index_user_collections_on_collection_id"
    t.index ["user_id"], name: "index_user_collections_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "video_game_details", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "developer"
    t.string "genre"
    t.string "platform"
    t.date "release_date"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "items", "collections"
  add_foreign_key "user_collections", "collections"
  add_foreign_key "user_collections", "users"
end
