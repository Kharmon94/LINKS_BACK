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
      return false unless due?
      return false unless any_channel_eligible?

      deliver_push if push_eligible?
      deliver_email if email_eligible?
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

  def deliver_push
    user.web_push_subscriptions.find_each do |subscription|
      WebPushSender.send_to!(
        subscription,
        title: notification_title,
        body: notification_body,
        url: deep_link_url
      )
    rescue Webpush::InvalidSubscription, Webpush::ExpiredSubscription
      subscription.destroy
    rescue Webpush::ResponseError => e
      subscription.destroy if e.response&.code.to_s == "410"
    end
  end

  def deliver_email
    if @entity.is_a?(Campaign)
      UserMailer.campaign_milestone(user, @entity, clicks: current_clicks).deliver_later
    else
      UserMailer.link_milestone(user, @entity, clicks: current_clicks).deliver_later
    end
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
