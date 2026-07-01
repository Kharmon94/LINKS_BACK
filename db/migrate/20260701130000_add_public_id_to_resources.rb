# frozen_string_literal: true

class AddPublicIdToResources < ActiveRecord::Migration[8.0]
  TABLES = %i[links campaigns workspaces users teams].freeze

  def up
    TABLES.each do |table|
      add_column table, :public_id, :string
    end

    TABLES.each do |table|
      backfill_public_ids(table)
    end

    TABLES.each do |table|
      change_column_null table, :public_id, false
      add_index table, :public_id, unique: true
    end
  end

  def down
    TABLES.each do |table|
      remove_index table, :public_id
      remove_column table, :public_id
    end
  end

  private

  def backfill_public_ids(table)
    model = table.to_s.classify.constantize
    model.reset_column_information

    model.find_each do |record|
      loop do
        candidate = SecureRandom.alphanumeric(12).downcase
        next if model.exists?(public_id: candidate)

        record.update_column(:public_id, candidate)
        break
      end
    end
  end
end
