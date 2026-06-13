# frozen_string_literal: true

module Api
  module V1
    class CampaignsController < BaseController
      include WorkspaceScoping

      before_action :require_campaigns_feature!
      load_and_authorize_resource through: :current_user, except: %i[index create assign_links unassign_links]
      before_action :set_campaign, only: %i[assign_links unassign_links]

      def index
        campaigns = scoped_campaigns.order(created_at: :desc)
        render json: { campaigns: campaigns.map(&:as_json_for_client) }
      end

      def show
        authorize! :read, @campaign
        render json: { campaign: @campaign.as_json_for_client(include_links: true) }
      end

      def create
        if current_user.at_campaign_limit?
          return render json: {
            error: "You've reached your campaign limit. Upgrade to create more campaigns.",
            upgrade_url: "/pricing"
          }, status: :forbidden
        end

        @campaign = current_user.campaigns.build(campaign_params)
        assign_workspace!(@campaign)
        authorize! :create, @campaign

        if @campaign.save
          render json: { campaign: @campaign.as_json_for_client }, status: :created
        else
          render json: { error: @campaign.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def update
        authorize! :update, @campaign
        if @campaign.update(campaign_params)
          render json: { campaign: @campaign.as_json_for_client }
        else
          render json: { error: @campaign.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize! :destroy, @campaign
        @campaign.destroy!
        head :no_content
      end

      def assign_links
        authorize! :assign_links, @campaign
        link_ids = Array(params[:link_ids]).map(&:to_s)
        links = current_user.links.where(id: link_ids)
        links.update_all(campaign_id: @campaign.id)
        render json: { campaign: @campaign.reload.as_json_for_client(include_links: true) }
      end

      def unassign_links
        authorize! :unassign_links, @campaign
        link_ids = Array(params[:link_ids]).map(&:to_s)
        @campaign.links.where(id: link_ids).update_all(campaign_id: nil)
        render json: { campaign: @campaign.reload.as_json_for_client(include_links: true) }
      end

      private

      def require_campaigns_feature!
        return if FeatureFlag.enabled?(:campaigns)

        render json: { error: "Campaigns feature is not enabled" }, status: :forbidden
      end

      def set_campaign
        @campaign = scoped_campaigns.find(params[:id])
      end

      def campaign_params
        p = params[:campaign].presence || params
        p.permit(:name, :description)
      end

      def assign_workspace!(campaign)
        return unless FeatureFlag.enabled?(:workspaces)

        workspace = current_user.active_workspace || current_user.accessible_workspaces.first
        campaign.workspace = workspace if workspace
      end
    end
  end
end
