# frozen_string_literal: true

class AddWorkspaceAndCustomDomainRefs < ActiveRecord::Migration[8.0]
  def change
    create_table :custom_domains do |t|
      t.references :user, null: false, foreign_key: true
      t.string :domain, null: false
      t.string :status, null: false, default: "pending"
      t.boolean :is_default, default: false, null: false
      t.string :verification_token, null: false
      t.datetime :verified_at
      t.timestamps
    end

    add_index :custom_domains, :domain, unique: true

    add_reference :links, :workspace, foreign_key: true
    add_reference :links, :custom_domain, foreign_key: true
  end
end
