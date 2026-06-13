# frozen_string_literal: true

namespace :links do
  desc "Report/repair links with custom_domain_id set (legacy silent frontend assignment). DRY_RUN=false to apply; optional LINK_IDS."
  task repair_platform_short_urls: :environment do
    dry_run = ENV["DRY_RUN"] != "false"
    platform_host = ENV.fetch("SHORT_LINK_HOST", "links.blackcollar.io")

    scope = Link.where.not(custom_domain_id: nil).includes(:custom_domain, :user)

    if ENV["LINK_IDS"].present?
      ids = ENV["LINK_IDS"].split(",").map(&:strip).reject(&:blank?)
      scope = scope.where(id: ids)
    end

    links = scope.order(:id).to_a

    puts "Platform host: #{platform_host}"
    puts "Mode: #{dry_run ? 'DRY RUN (set DRY_RUN=false to apply)' : 'APPLY'}"
    puts "Criteria: custom_domain_id IS NOT NULL"
    puts "  Links matching this were assigned a branded domain at create time."
    puts "  The legacy dashboard bug sent custom_domain_id even when Customize was closed,"
    puts "  so affected rows should use the platform host after repair."
    puts "Found #{links.size} link(s)."
    puts

    links.each do |link|
      domain = link.custom_domain&.domain || "(missing domain #{link.custom_domain_id})"
      puts "  ##{link.id}  #{link.short_code}  user=#{link.user.email}  domain=#{domain}"
    end

    if links.empty?
      puts "Nothing to do."
      next
    end

    if dry_run
      puts
      puts "No changes made. Re-run with DRY_RUN=false to nullify custom_domain_id."
      puts "Example: bundle exec rake links:repair_platform_short_urls DRY_RUN=false"
      puts "Targeted: bundle exec rake links:repair_platform_short_urls LINK_IDS=4 DRY_RUN=false"
    else
      updated = 0
      links.each do |link|
        link.update_column(:custom_domain_id, nil)
        updated += 1
      end
      puts
      puts "Nullified custom_domain_id on #{updated} link(s)."
    end
  end
end
