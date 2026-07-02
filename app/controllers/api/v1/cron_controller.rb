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
        push_count = User.find_each.count { |u| u.notification_preferences_hash["push_link_alerts"] }
        email_count = User.find_each.count { |u| u.notification_preferences_hash["email_link_alerts"] }
        render json: {
          ok: true,
          checked: 0,
          eligibleUsers: { push: push_count, email: email_count },
          message: "Link milestone job stub"
        }
      end

      private

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
