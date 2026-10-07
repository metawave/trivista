class CreateDomainSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :iss, null: false
      t.string :sub, null: false
      t.string :name
      t.string :groups, array: true, null: false, default: []
      t.boolean :admin, null: false, default: false
      t.datetime :deactivated_at
      t.timestamps

      t.index [ :iss, :sub ], unique: true
    end

    create_table :owners do |t|
      t.references :user, foreign_key: true, index: { unique: true }
      t.string :group_name, index: { unique: true }
      t.bigint :occurrence_count, null: false, default: 0
      t.timestamps

      t.check_constraint "(user_id IS NULL) <> (group_name IS NULL)", name: "owners_user_xor_group"
      t.check_constraint "occurrence_count >= 0", name: "owners_occurrence_count_non_negative"
    end

    create_table :projects do |t|
      t.references :owner, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.string :visibility, null: false
      t.string :visibility_group
      t.timestamps

      t.index [ :owner_id, :name ], unique: true
      t.check_constraint "visibility IN ('user', 'group', 'public')", name: "projects_visibility_known"
    end

    create_table :repos do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :name, null: false
      t.bigint :default_branch_id
      t.boolean :default_branch_manual, null: false, default: false
      t.timestamps

      t.index [ :project_id, :name ], unique: true
    end

    create_table :branches do |t|
      t.references :repo, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :name, null: false
      t.timestamps

      t.index [ :repo_id, :name ], unique: true
    end

    add_foreign_key :repos, :branches, column: :default_branch_id, on_delete: :nullify

    create_table :artifacts do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :category, null: false
      t.string :name, null: false
      t.timestamps

      t.index [ :project_id, :category, :name ], unique: true
      t.check_constraint "category IN ('container_image', 'source', 'vm', 'cyclonedx', 'spdx', 'aws_account')",
        name: "artifacts_category_known"
    end

    create_table :service_accounts do |t|
      t.references :owner, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.timestamps

      t.index [ :owner_id, :name ], unique: true
    end

    create_table :upload_tokens do |t|
      t.references :service_account, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :token_digest, null: false, index: { unique: true }
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
    end

    create_table :scans do |t|
      t.references :branch, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :artifact, null: false, foreign_key: { on_delete: :cascade }
      t.references :service_account, null: false, foreign_key: true
      t.string :commit_sha, null: false
      t.string :tag
      t.string :trigger, null: false, default: "unknown"
      t.string :reported_artifact_type, null: false
      t.string :reported_artifact_name, null: false
      t.integer :schema_version
      t.datetime :report_created_at
      t.string :trivy_version
      t.string :os_family
      t.string :os_name
      t.jsonb :counts, null: false, default: {}
      t.timestamps

      t.index [ :branch_id, :artifact_id, :created_at, :id ], name: "index_scans_for_predecessor"
      t.check_constraint "trigger IN ('push', 'tag', 'schedule', 'manual', 'pr', 'unknown')", name: "scans_trigger_known"
    end

    create_table :findings do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :finding_type, null: false
      t.string :fingerprint, null: false
      t.string :identifier, null: false
      t.string :namespace
      t.string :misconfiguration_type
      t.string :pkg_name
      t.string :target
      t.string :resource
      t.string :provider
      t.string :service
      t.string :category
      t.string :title
      t.text :description
      t.text :resolution
      t.string :primary_url
      t.string :references, array: true, null: false, default: []
      t.datetime :published_at
      t.datetime :last_modified_at
      t.timestamps

      t.index [ :project_id, :fingerprint ], unique: true
      t.check_constraint "finding_type IN ('vulnerability', 'misconfiguration', 'secret', 'license')",
        name: "findings_type_known"
    end

    create_table :occurrences do |t|
      t.references :scan, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :finding, null: false, foreign_key: { on_delete: :cascade }
      t.string :installed_version
      t.string :location
      t.string :fixed_version
      t.string :status
      t.string :severity, null: false
      t.integer :start_line
      t.integer :end_line
      t.float :confidence
      t.timestamps

      t.index [ :scan_id, :finding_id, :installed_version, :location ], unique: true, nulls_not_distinct: true,
        name: "index_occurrences_identity"
      t.check_constraint "severity IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'UNKNOWN')", name: "occurrences_severity_known"
    end
  end
end
