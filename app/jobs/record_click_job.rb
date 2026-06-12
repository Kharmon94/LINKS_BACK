# frozen_string_literal: true

class RecordClickJob < ApplicationJob
  queue_as :default

  def perform(link_id, metadata, pool_entry_id: nil, destination_url: nil)
    link = Link.find_by(id: link_id)
    return unless link

    pool_entry = pool_entry_id.present? ? link.pool_entries.find_by(id: pool_entry_id) : nil
    link.record_click_from_metadata!(
      metadata.symbolize_keys,
      pool_entry: pool_entry,
      destination_url: destination_url
    )
  end
end
