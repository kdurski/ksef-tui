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

ActiveRecord::Schema[8.1].define(version: 2026_04_24_210000) do
  create_table "ksef_api_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "duration"
    t.text "error"
    t.string "http_method"
    t.string "path"
    t.text "request_body"
    t.json "request_headers"
    t.text "response_body"
    t.json "response_headers"
    t.integer "status"
    t.datetime "timestamp"
    t.datetime "updated_at", null: false
  end

  create_table "ksef_login_requests", force: :cascade do |t|
    t.string "access_token"
    t.string "access_token_valid_until"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "host", null: false
    t.string "nip", null: false
    t.string "profile_id"
    t.string "profile_name"
    t.string "refresh_token"
    t.string "refresh_token_valid_until"
    t.string "seed_token"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_ksef_login_requests_on_profile_id"
    t.index ["status"], name: "index_ksef_login_requests_on_status"
  end
end
