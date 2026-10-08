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

ActiveRecord::Schema[8.1].define(version: 2026_10_08_065727) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "artifacts", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "category", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "category", "name"], name: "index_artifacts_on_project_id_and_category_and_name", unique: true
    t.check_constraint "category::text = ANY (ARRAY['container_image'::character varying, 'source'::character varying, 'vm'::character varying, 'cyclonedx'::character varying, 'spdx'::character varying, 'aws_account'::character varying]::text[])", name: "artifacts_category_known"
  end

  create_table "branches", force: :cascade do |t|
    t.bigint "repo_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["repo_id", "name"], name: "index_branches_on_repo_id_and_name", unique: true
  end

  create_table "findings", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "finding_type", null: false
    t.string "fingerprint", null: false
    t.string "identifier", null: false
    t.string "namespace"
    t.string "misconfiguration_type"
    t.string "pkg_name"
    t.string "target"
    t.string "resource"
    t.string "provider"
    t.string "service"
    t.string "category"
    t.string "title"
    t.text "description"
    t.text "resolution"
    t.string "primary_url"
    t.string "references", default: [], null: false, array: true
    t.datetime "published_at"
    t.datetime "last_modified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "fingerprint"], name: "index_findings_on_project_id_and_fingerprint", unique: true
    t.check_constraint "finding_type::text = ANY (ARRAY['vulnerability'::character varying, 'misconfiguration'::character varying, 'secret'::character varying, 'license'::character varying]::text[])", name: "findings_type_known"
  end

  create_table "occurrences", force: :cascade do |t|
    t.bigint "scan_id", null: false
    t.bigint "finding_id", null: false
    t.string "installed_version"
    t.string "location"
    t.string "fixed_version"
    t.string "status"
    t.string "severity", null: false
    t.integer "start_line"
    t.integer "end_line"
    t.float "confidence"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["finding_id"], name: "index_occurrences_on_finding_id"
    t.index ["scan_id", "finding_id", "installed_version", "location"], name: "index_occurrences_identity", unique: true, nulls_not_distinct: true
    t.check_constraint "severity::text = ANY (ARRAY['CRITICAL'::character varying, 'HIGH'::character varying, 'MEDIUM'::character varying, 'LOW'::character varying, 'UNKNOWN'::character varying]::text[])", name: "occurrences_severity_known"
  end

  create_table "owners", force: :cascade do |t|
    t.bigint "user_id"
    t.string "group_name"
    t.bigint "occurrence_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_name"], name: "index_owners_on_group_name", unique: true
    t.index ["user_id"], name: "index_owners_on_user_id", unique: true
    t.check_constraint "(user_id IS NULL) <> (group_name IS NULL)", name: "owners_user_xor_group"
    t.check_constraint "occurrence_count >= 0", name: "owners_occurrence_count_non_negative"
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "owner_id", null: false
    t.string "name", null: false
    t.string "visibility", null: false
    t.string "visibility_group"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id", "name"], name: "index_projects_on_owner_id_and_name", unique: true
    t.check_constraint "visibility::text = ANY (ARRAY['user'::character varying, 'group'::character varying, 'public'::character varying]::text[])", name: "projects_visibility_known"
  end

  create_table "repos", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "name", null: false
    t.bigint "default_branch_id"
    t.boolean "default_branch_manual", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_repos_on_project_id_and_name", unique: true
  end

  create_table "scans", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.bigint "artifact_id", null: false
    t.bigint "service_account_id", null: false
    t.string "commit_sha", null: false
    t.string "tag"
    t.string "trigger", default: "unknown", null: false
    t.string "reported_artifact_type", null: false
    t.string "reported_artifact_name", null: false
    t.integer "schema_version"
    t.datetime "report_created_at"
    t.string "trivy_version"
    t.string "os_family"
    t.string "os_name"
    t.jsonb "counts", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "occurrences_pruned_at"
    t.index ["artifact_id"], name: "index_scans_on_artifact_id"
    t.index ["branch_id", "artifact_id", "created_at", "id"], name: "index_scans_for_predecessor"
    t.index ["service_account_id"], name: "index_scans_on_service_account_id"
    t.check_constraint "trigger::text = ANY (ARRAY['push'::character varying, 'tag'::character varying, 'schedule'::character varying, 'manual'::character varying, 'pr'::character varying, 'unknown'::character varying]::text[])", name: "scans_trigger_known"
  end

  create_table "service_accounts", force: :cascade do |t|
    t.bigint "owner_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id", "name"], name: "index_service_accounts_on_owner_id_and_name", unique: true
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "upload_tokens", force: :cascade do |t|
    t.bigint "service_account_id", null: false
    t.bigint "created_by_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_upload_tokens_on_created_by_id"
    t.index ["service_account_id"], name: "index_upload_tokens_on_service_account_id"
    t.index ["token_digest"], name: "index_upload_tokens_on_token_digest", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "iss", null: false
    t.string "sub", null: false
    t.string "name"
    t.string "groups", default: [], null: false, array: true
    t.boolean "admin", default: false, null: false
    t.datetime "deactivated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["iss", "sub"], name: "index_users_on_iss_and_sub", unique: true
  end

  add_foreign_key "artifacts", "projects", on_delete: :cascade
  add_foreign_key "branches", "repos", on_delete: :cascade
  add_foreign_key "findings", "projects", on_delete: :cascade
  add_foreign_key "occurrences", "findings", on_delete: :cascade
  add_foreign_key "occurrences", "scans", on_delete: :cascade
  add_foreign_key "owners", "users"
  add_foreign_key "projects", "owners"
  add_foreign_key "repos", "branches", column: "default_branch_id", on_delete: :nullify
  add_foreign_key "repos", "projects", on_delete: :cascade
  add_foreign_key "scans", "artifacts", on_delete: :cascade
  add_foreign_key "scans", "branches", on_delete: :cascade
  add_foreign_key "scans", "service_accounts"
  add_foreign_key "service_accounts", "owners"
  add_foreign_key "upload_tokens", "service_accounts"
  add_foreign_key "upload_tokens", "users", column: "created_by_id"
end
