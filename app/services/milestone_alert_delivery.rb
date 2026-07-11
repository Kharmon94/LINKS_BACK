# frozen_string_literal: true

class MilestoneAlertDelivery
  def self.call(entity)
    new(entity).call
  end

  def self.due?(entity)
    new(entity).due?
  end

  def initialize(entity)
    @entity = entity
  end

  def call
    @entity.with_lock do
      @entity.reload
      return false unless due?
      return false unless any_channel_eligible?

      delivered = false
      if push_eligible?
        push_ok = deliver_push
        delivered = true if push_ok
        warn_push_missed! unless push_ok
      end
      delivered = true if email_eligible? && deliver_email

      # Only advance when something was actually sent/queued. Otherwise a link with
      # push enabled but no device subscription would silently burn the milestone.
      return false unless delivered

      advance_baselines!
      true
    end
  end

  def due?
    case @entity.alert_interval_kind
    when "time"
      time_due?
    when "clicks"
      clicks_due?
    else
      false
    end
  end

  private

  def user
    @user ||= @entity.user
  end

  def prefs
    @prefs ||= user.notification_preferences_hash
  end

  def push_eligible?
    @entity.push_alerts_enabled && prefs["push_link_alerts"]
  end

  def email_eligible?
    @entity.email_alerts_enabled && prefs["email_link_alerts"]
  end

  def any_channel_eligible?
    push_eligible? || email_eligible?
  end

  def time_due?
    baseline = @entity.last_alerted_at || @entity.created_at
    return false if baseline.blank?

    interval = @entity.alert_interval_value.to_i.public_send(@entity.alert_interval_unit)
    Time.current - baseline >= interval
  end

  def clicks_due?
    (current_clicks - @entity.last_alerted_clicks.to_i) >= @entity.alert_interval_value.to_i
  end

  def current_clicks
    if @entity.is_a?(Campaign)
      @entity.total_clicks
    else
      @entity.clicks_count
    end
  end

  def entity_name
    if @entity.is_a?(Campaign)
      @entity.name
    else
      @entity.name.presence || "Untitled"
    end
  end

  def entity_label
    @entity.is_a?(Campaign) ? "campaign" : "link"
  end

  def deep_link_url
    path = @entity.is_a?(Campaign) ? "/campaigns/#{@entity.public_id}" : "/links/#{@entity.public_id}"
    "#{frontend_origin}#{path}"
  end

  def frontend_origin
    ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173").chomp("/")
  end

  def notification_title
    "Links"
  end

  def notification_body
    %(Your #{entity_label} "#{entity_name}" has #{current_clicks} clicks)
  end

  # Returns true if at least one push was sent successfully.
  def deliver_push
    sent = false
    user.web_push_subscriptions.find_each do |subscription|
      WebPushSender.send_to!(
        subscription,
        title: notification_title,
        body: notification_body,
        url: deep_link_url
      )
      sent = true
    rescue Webpush::InvalidSubscription, Webpush::ExpiredSubscription
      subscription.destroy
    rescue Webpush::ResponseError => e
      subscription.destroy if e.response&.code.to_s == "410"
    rescue KeyError, ArgumentError => e
      Rails.logger.error("[MilestoneAlertDelivery] push config error: #{e.message}")
      break
    rescue StandardError => e
      Rails.logger.error("[MilestoneAlertDelivery] push failed: #{e.class}: #{e.message}")
    end
    sent
  end

  def warn_push_missed!
    sub_count = user.web_push_subscriptions.count
    Rails.logger.warn(
      "[MilestoneAlertDelivery] push eligible but no successful send " \
      "user_id=#{user.id} #{entity_label}_id=#{@entity.id} subscriptions=#{sub_count}"
    )
  end

  # Returns true if the mailer was enqueued.
  def deliver_email
    if @entity.is_a?(Campaign)
      UserMailer.campaign_milestone(user, @entity, clicks: current_clicks).deliver_later
    else
      UserMailer.link_milestone(user, @entity, clicks: current_clicks).deliver_later
    end
    true
  end

  def advance_baselines!
    attrs = {}
    case @entity.alert_interval_kind
    when "time"
      attrs[:last_alerted_at] = Time.current
    when "clicks"
      attrs[:last_alerted_clicks] = current_clicks
    end
    @entity.update!(attrs) if attrs.any?
  end
end
