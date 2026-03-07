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

ActiveRecord::Schema[8.1].define(version: 2026_03_07_023730) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "badges", force: :cascade do |t|
    t.string "badge_type"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "icon"
    t.string "name"
    t.boolean "seeded"
    t.integer "threshold"
    t.datetime "updated_at", null: false
  end

  create_table "books", force: :cascade do |t|
    t.string "author"
    t.string "back_cover"
    t.string "book_condition"
    t.string "cover_image"
    t.datetime "created_at", null: false
    t.boolean "flagged"
    t.string "front_cover"
    t.string "isbn"
    t.integer "preferred_location_id"
    t.text "rejection_reason"
    t.string "status"
    t.text "submission_notes"
    t.string "submission_status"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_books_on_user_id"
  end

  create_table "finds", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.datetime "created_at", null: false
    t.datetime "found_at"
    t.bigint "label_id", null: false
    t.string "photo"
    t.integer "points_awarded"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["book_id"], name: "index_finds_on_book_id"
    t.index ["label_id"], name: "index_finds_on_label_id"
    t.index ["user_id"], name: "index_finds_on_user_id"
  end

  create_table "friendships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "friend_id"
    t.string "status"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_friendships_on_user_id"
  end

  create_table "labels", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.datetime "created_at", null: false
    t.bigint "location_id", null: false
    t.string "qr_code"
    t.string "status", default: "created"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["book_id"], name: "index_labels_on_book_id"
    t.index ["location_id"], name: "index_labels_on_location_id"
    t.index ["user_id"], name: "index_labels_on_user_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "address_line_1"
    t.string "address_line_2"
    t.string "city"
    t.string "contact_name"
    t.datetime "created_at", null: false
    t.decimal "latitude"
    t.string "location_type"
    t.decimal "longitude"
    t.string "name"
    t.integer "nominated_by"
    t.text "nomination_notes"
    t.string "nomination_status"
    t.string "state"
    t.datetime "updated_at", null: false
    t.boolean "verified"
    t.datetime "verified_at"
    t.integer "verified_by"
    t.string "website"
    t.string "zip_code"
  end

  create_table "user_badges", force: :cascade do |t|
    t.datetime "awarded_at"
    t.bigint "badge_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["badge_id"], name: "index_user_badges_on_badge_id"
    t.index ["user_id"], name: "index_user_badges_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar"
    t.text "bio"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "points"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "books", "users"
  add_foreign_key "finds", "books"
  add_foreign_key "finds", "labels"
  add_foreign_key "finds", "users"
  add_foreign_key "friendships", "users"
  add_foreign_key "labels", "books"
  add_foreign_key "labels", "locations"
  add_foreign_key "labels", "users"
  add_foreign_key "user_badges", "badges"
  add_foreign_key "user_badges", "users"
end
