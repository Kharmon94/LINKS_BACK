# frozen_string_literal: true

module Api
  module V1
    class AccountController < BaseController
      def update
        authorize! :update, current_user
        if current_user.update(account_params)
          render json: { user: current_user.as_json_for_client }
        else
          render json: { error: current_user.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def update_password
        authorize! :update, current_user
        current = params[:current_password].to_s
        new_password = params[:password].to_s
        confirmation = params[:password_confirmation].to_s

        unless current_user.valid_password?(current)
          return render json: { error: "Current password is incorrect" }, status: :unauthorized
        end

        current_user.password = new_password
        current_user.password_confirmation = confirmation.presence || new_password
        unless current_user.save
          return render json: { error: current_user.errors.full_messages.to_sentence },
                        status: :unprocessable_entity
        end

        current_user.update!(password_set_at: Time.current) if current_user.password_set_at.blank?
        render json: { user: current_user.as_json_for_client }
      end

      def notification_preferences
        authorize! :show, current_user
        render json: {
          notificationPreferences: current_user.notification_preferences_hash,
          webPushConfigured: ENV["VAPID_PUBLIC_KEY"].present?
        }
      end

      def update_notification_preferences
        authorize! :update, current_user
        prefs = current_user.notification_preferences_hash.merge(permitted_notification_prefs)
        current_user.update!(notification_preferences: prefs)
        render json: { notificationPreferences: current_user.notification_preferences_hash }
      end

      def active_workspace
        authorize! :update, current_user
        workspace = HasPublicId.find_by_param!(current_user.accessible_workspaces, params[:workspace_id])
        unless workspace
          return render json: { error: "Workspace not found" }, status: :not_found
        end

        current_user.update!(active_workspace: workspace)
        render json: { user: current_user.as_json_for_client }
      end

      private

      def account_params
        params.permit(:name)
      end

      def permitted_notification_prefs
        raw = params[:notification_preferences] || params[:notificationPreferences] || {}
        raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
        raw = raw.stringify_keys
        result = {}

        User::NOTIFICATION_CHANNEL_KEYS.each do |key|
          result[key] = User.cast_notification_bool(raw[key]) if raw.key?(key)
        end

        if raw.key?("link_alerts")
          value = User.cast_notification_bool(raw["link_alerts"])
          result["push_link_alerts"] = value unless raw.key?("push_link_alerts")
          result["email_link_alerts"] = value unless raw.key?("email_link_alerts")
        end

        if raw.key?("weekly_reports")
          value = User.cast_notification_bool(raw["weekly_reports"])
          result["push_weekly_reports"] = value unless raw.key?("push_weekly_reports")
          result["email_weekly_reports"] = value unless raw.key?("email_weekly_reports")
        end

        if raw.key?("marketing_emails")
          value = User.cast_notification_bool(raw["marketing_emails"])
          result["email_marketing"] = value unless raw.key?("email_marketing")
        end

        if raw.key?("email_notifications") && !User.cast_notification_bool(raw["email_notifications"])
          result["email_link_alerts"] = false unless raw.key?("email_link_alerts")
          result["email_weekly_reports"] = false unless raw.key?("email_weekly_reports")
          result["email_marketing"] = false unless raw.key?("email_marketing")
        end

        result
      end
    end
  end
end
