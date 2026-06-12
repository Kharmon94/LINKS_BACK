# frozen_string_literal: true

namespace :analytics do
  desc "Backfill links.clicks_count from click_events (run once if counts drift)"
  task reconcile_clicks: :environment do
    updated = 0
    Link.find_each do |link|
      event_count = link.click_events.count
      next if link.clicks_count == event_count

      link.update_column(:clicks_count, event_count)
      updated += 1
    end
    puts "Reconciled clicks_count for #{updated} link(s)."
  end
end
