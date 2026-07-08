# frozen_string_literal: true

module Analytics
  class Aggregator
    PERIODS = {
      "7D" => 7.days,
      "30D" => 30.days,
      "90D" => 90.days,
      "1Y" => 1.year,
      "ALL" => nil
    }.freeze

    DEVICE_COLORS = ClickMetadata::DEVICE_COLORS

    def initialize(scope)
      @scope = scope
      @link_ids = resolve_link_ids
    end

    def overview_for(user)
      links = @scope
      campaigns = scoped_campaigns_for(user)
      link_ids = links.select(:id)
      events = ClickEvent.where(link_id: link_ids)
      total_clicks = events.count
      week_ago = 7.days.ago
      clicks_this_week = events.where("clicked_at >= ?", week_ago).count
      clicks_prev_week = events.where(clicked_at: (14.days.ago)...(week_ago)).count
      growth = week_over_week_click_growth(clicks_this_week, clicks_prev_week)

      result = {
        totalClicks: total_clicks,
        totalLinks: links.count,
        totalCampaigns: campaigns.count,
        clickGrowth: growth,
        topLinks: top_links(links, total_clicks),
        topCampaigns: top_campaigns(campaigns, total_clicks),
        topWorkspaces: top_workspaces(user, links, total_clicks),
        clicksOverTime: clicks_over_time_by_period(events),
        deviceBreakdown: device_breakdown(events),
        recentClicks: recent_clicks(events)
      }
      result
    end

    def link_analytics(link)
      events = ClickEvent.where(link_id: link.id)
      total = events.count

      analytics = {
        link: link.as_json_for_client,
        totalClicks: total,
        quickStats: quick_stats(events, 1),
        clicksOverTime: clicks_over_time_by_period(events),
        deviceBreakdown: device_breakdown(events),
        topLocations: top_locations(events),
        referrerBreakdown: referrer_breakdown(events),
        recentClicks: recent_clicks(events)
      }
      analytics[:poolBreakdown] = pool_breakdown(events, link) if link.randomizer?
      analytics
    end

    def campaign_analytics(campaign)
      link_ids = campaign.links.pluck(:id)
      events = ClickEvent.where(link_id: link_ids)
      total = events.count

      {
        campaign: campaign.as_json_for_client,
        totalClicks: total,
        quickStats: quick_stats(events, campaign.links.count, created_at: campaign.created_at),
        clicksOverTime: clicks_over_time_by_period(events),
        deviceBreakdown: device_breakdown(events),
        topLocations: top_locations(events),
        referrerBreakdown: referrer_breakdown(events),
        recentClicks: recent_clicks(events.limit(10))
      }
    end

    private

    def week_over_week_click_growth(clicks_this_week, clicks_prev_week)
      return 0.0 if clicks_this_week == clicks_prev_week
      return 100.0 if clicks_prev_week.zero? && clicks_this_week.positive?

      ((clicks_this_week - clicks_prev_week).to_f / clicks_prev_week * 100).round(1)
    end

    def resolve_link_ids
      if @scope.is_a?(Link)
        [@scope.id]
      elsif @scope.is_a?(Campaign)
        @scope.links.pluck(:id)
      elsif @scope.respond_to?(:pluck)
        @scope.pluck(:id)
      else
        Array(@scope)
      end
    end

    def scoped_campaigns_for(user)
      if FeatureFlag.enabled_for?(user, :workspaces) && user.active_workspace_id.present?
        user.campaigns.where(workspace_id: user.active_workspace_id)
      else
        user.campaigns
      end
    end

    def top_links(links, total_clicks)
      link_ids = links.pluck(:id)
      return [] if link_ids.empty?

      counts_by_link = ClickEvent.where(link_id: link_ids).group(:link_id).count
      links.where(id: link_ids).sort_by { |link| -(counts_by_link[link.id] || 0) }.first(5).map do |link|
        clicks = counts_by_link[link.id] || 0
        {
          shortUrl: link.as_json_for_client[:shortUrl],
          clicks: clicks,
          percentage: total_clicks.positive? ? (clicks.to_f / total_clicks * 100).round : 0
        }
      end
    end

    def top_campaigns(campaigns, total_clicks)
      campaigns.map { |c| [c, ClickEvent.where(link_id: c.links.select(:id)).count] }
               .sort_by { |_, clicks| -clicks }
               .first(5)
               .map do |campaign, clicks|
        {
          campaign: campaign.name,
          clicks: clicks,
          percentage: total_clicks.positive? ? (clicks.to_f / total_clicks * 100).round : 0
        }
      end
    end

    def top_workspaces(user, links, total_clicks)
      return [] unless FeatureFlag.enabled_for?(user, :workspaces)

      workspace_ids = links.where.not(workspace_id: nil).distinct.pluck(:workspace_id)
      return [] if workspace_ids.empty?

      Workspace.where(id: workspace_ids).map do |workspace|
        workspace_link_ids = links.where(workspace_id: workspace.id).select(:id)
        clicks = ClickEvent.where(link_id: workspace_link_ids).count
        {
          name: workspace.name,
          clicks: clicks,
          percentage: total_clicks.positive? ? (clicks.to_f / total_clicks * 100).round : 0
        }
      end.sort_by { |row| -row[:clicks] }.first(5)
    end

    def pool_breakdown(events, link)
      counts_by_entry = events.where.not(pool_entry_id: nil).group(:pool_entry_id).count
      total = events.count

      link.pool_entries.map do |entry|
        clicks = counts_by_entry[entry.id] || 0
        {
          poolEntryId: entry.id.to_s,
          url: entry.destination_url,
          weight: entry.weight,
          clicks: clicks,
          percentage: total.positive? ? (clicks.to_f / total * 100).round : 0
        }
      end.sort_by { |row| -row[:clicks] }
    end

    def quick_stats(events, links_count, created_at: nil)
      last_7 = events.where("clicked_at >= ?", 7.days.ago).count
      last_30 = events.where("clicked_at >= ?", 30.days.ago).count
      all_time = events.count
      avg_daily = last_30.positive? ? (last_30 / 30.0).round : 0
      peak_day = events.group(Arel.sql(date_sql("clicked_at"))).count.values.max || 0

      stats = {
        last7Days: last_7,
        last30Days: last_30,
        allTime: all_time,
        totalLinks: links_count,
        avgDailyClicks: avg_daily,
        peakDay: peak_day,
        countries: events.where.not(country: [nil, ""]).distinct.count(:country),
        activeDays: events.distinct.count(Arel.sql(date_sql("clicked_at")))
      }
      stats[:createdAt] = created_at&.iso8601 if created_at
      stats
    end

    def clicks_over_time_by_period(events)
      PERIODS.transform_values do |duration|
        scoped = duration ? events.where("clicked_at >= ?", duration.ago) : events
        bucket_clicks(scoped, duration)
      end
    end

    def bucket_clicks(events, duration)
      return [] if events.none?

      date_expr = date_sql("clicked_at")
      month_expr = month_sql("clicked_at")

      if duration.nil? || duration >= 1.year
        events.group(Arel.sql(month_expr))
              .count
              .sort_by { |k, _| k }
              .map { |date, clicks| { date: format_month(date), clicks: clicks } }
      elsif duration && duration >= 90.days
        events.group(Arel.sql(date_expr))
              .count
              .sort_by { |k, _| k }
              .each_slice((events.count / 8.0).ceil)
              .map do |slice|
          { date: slice.first[0].to_s, clicks: slice.sum { |_, c| c } }
        end
      else
        events.group(Arel.sql(date_expr))
              .count
              .sort_by { |k, _| k }
              .map { |date, clicks| { date: format_day(date), clicks: clicks } }
      end
    end

    def date_sql(column)
      if postgresql?
        "DATE(#{column})"
      else
        "date(#{column})"
      end
    end

    def month_sql(column)
      if postgresql?
        "TO_CHAR(#{column}, 'YYYY-MM')"
      else
        "strftime('%Y-%m', #{column})"
      end
    end

    def postgresql?
      ActiveRecord::Base.connection.adapter_name.match?(/PostgreSQL/i)
    end

    def format_day(date_str)
      Date.parse(date_str.to_s).strftime("%b %-d")
    rescue ArgumentError
      date_str.to_s
    end

    def format_month(date_str)
      Date.strptime("#{date_str}-01", "%Y-%m-%d").strftime("%b %y")
    rescue ArgumentError
      date_str.to_s
    end

    def device_breakdown(events)
      counts = events.group(:device_type).count
      counts.map do |device, count|
        name = device.presence || "Unknown"
        {
          name: name,
          value: count,
          color: DEVICE_COLORS[name] || "#9AA0A6"
        }
      end
    end

    def top_locations(events)
      events.where.not(city: [nil, ""])
            .group(:city, :country)
            .count
            .sort_by { |_, c| -c }
            .first(5)
            .map do |(city, country), clicks|
        { city: city, country: country, clicks: clicks }
      end
    end

    def referrer_breakdown(events)
      events.group(:referrer).count.map do |referrer, count|
        source = referrer.present? ? URI.parse(referrer).host.to_s.gsub(/^www\./, "") : "Direct"
        { source: source.presence || "Direct", clicks: count }
      rescue URI::InvalidURIError
        { source: "Direct", clicks: count }
      end.sort_by { |r| -r[:clicks] }.first(10)
    end

    def recent_clicks(events)
      events.order(clicked_at: :desc).limit(10).includes(:link).map(&:as_json_for_client)
    end
  end
end
