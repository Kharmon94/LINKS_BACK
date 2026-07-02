# frozen_string_literal: true

module Api
  module V1
    class PwaController < BaseController
      def confirm_install
        if current_user.pwa_installed_at.nil?
          current_user.update!(pwa_installed_at: Time.current)
        end

        render json: { user: current_user.as_json_for_client }
      end
    end
  end
end
