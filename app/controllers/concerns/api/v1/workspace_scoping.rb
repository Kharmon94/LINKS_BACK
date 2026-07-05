# frozen_string_literal: true

module Api
  module V1
    module WorkspaceScoping
      extend ActiveSupport::Concern

      private

      def scoped_links
        current_user.scoped_links
      end

      def scoped_campaigns
        if FeatureFlag.enabled_for?(current_user, :workspaces) && current_user.active_workspace_id.present?
          current_user.campaigns.where(workspace_id: current_user.active_workspace_id)
        else
          current_user.campaigns
        end
      end
    end
  end
end
