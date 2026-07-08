# frozen_string_literal: true

module AlertPreferences
  extend ActiveSupport::Concern

  ALERT_INTERVAL_KINDS = %w[time clicks].freeze
  ALERT_INTERVAL_UNITS = %w[days weeks months years].freeze

  included do
    validates :alert_interval_value, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: false
    validates :alert_interval_kind, inclusion: { in: ALERT_INTERVAL_KINDS }
    validates :alert_interval_unit, inclusion: { in: ALERT_INTERVAL_UNITS }, if: :time_based_alert_interval?
  end

  def time_based_alert_interval?
    alert_interval_kind == "time"
  end

  def alert_preferences_as_json
    {
      pushAlertsEnabled: push_alerts_enabled,
      emailAlertsEnabled: email_alerts_enabled,
      alertIntervalKind: alert_interval_kind,
      alertIntervalValue: alert_interval_value,
      alertIntervalUnit: alert_interval_unit
    }
  end
end
