# frozen_string_literal: true

module Api
  module V1
    class CronController < ApplicationController
      before_action :verify_cron_secret!, only: [:trial_reminders]

      def trial_reminders
        render json: { ok: true, processed: 0 }
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
