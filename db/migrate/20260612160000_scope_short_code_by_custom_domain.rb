# frozen_string_literal: true

class ScopeShortCodeByCustomDomain < ActiveRecord::Migration[8.0]
  def change
    remove_index :links, :short_code, name: "index_links_on_short_code"

    add_index :links, :short_code,
              unique: true,
              where: "custom_domain_id IS NULL",
              name: "index_links_on_short_code_platform"

    add_index :links, %i[short_code custom_domain_id],
              unique: true,
              where: "custom_domain_id IS NOT NULL",
              name: "index_links_on_short_code_and_custom_domain"
  end
end
