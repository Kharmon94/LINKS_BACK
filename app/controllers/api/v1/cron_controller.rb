# frozen_string_literal: true

module Api
  module V1
    class CronController < ApplicationController
      before_action :verify_cron_secret!, only: %i[trial_reminders weekly_reports link_milestones]

      def trial_reminders
        render json: { ok: true, processed: 0 }
      end

      def weekly_reports
        push_count = User.find_each.count { |u| u.notification_preferences_hash["push_weekly_reports"] }
        email_count = User.find_each.count { |u| u.notification_preferences_hash["email_weekly_reports"] }
        render json: {
          ok: true,
          enqueued: 0,
          eligibleUsers: { push: push_count, email: email_count },
          message: "Weekly report job stub"
        }
      end

      def link_milestones
        checked = 0
        enqueued = 0

        time_alert_scope(Link).find_each do |link|
          checked += 1
          next unless MilestoneAlertDelivery.due?(link)

          DeliverMilestoneAlertJob.perform_later("Link", link.id)
          enqueued += 1
        end

        time_alert_scope(Campaign).find_each do |campaign|
          checked += 1
          next unless MilestoneAlertDelivery.due?(campaign)

          DeliverMilestoneAlertJob.perform_later("Campaign", campaign.id)
          enqueued += 1
        end

        render json: { ok: true, checked: checked, enqueued: enqueued }
      end

      private

      def time_alert_scope(model)
        model.where(alert_interval_kind: "time")
             .where("push_alerts_enabled = ? OR email_alerts_enabled = ?", true, true)
      end

      def verify_cron_secret!
        secret = ENV["CRON_SECRET"].presence
        return if secret.blank?

        token = request.headers["Authorization"].to_s[/Bearer (.+)/, 1].to_s
        param = params[:secret].to_s
        ok = ActiveSupport::SecurityUtils.secure_compare(token, secret) ||
             ActiveSupport::SecurityUtils.secure_compare(param, secret)
        return if ok

        head :unauthorized
      end
    end
  end
end
