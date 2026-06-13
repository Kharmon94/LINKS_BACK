# frozen_string_literal: true

module Api
  module V1
    class AnalyticsController < BaseController
      include WorkspaceScoping

      before_action :authorize_analytics!

      def overview
        data = Analytics::Aggregator.new(scoped_links).overview_for(current_user)
        render json: { analytics: data, generatedAt: Time.current.iso8601 }
      end

      def link_analytics
        link = scoped_links.find(link_id_param)
        authorize! :show, link
        data = Analytics::Aggregator.new(link).link_analytics(link)
        render json: { analytics: data, generatedAt: Time.current.iso8601 }
      end

      def campaign_analytics
        campaign = scoped_campaigns.find(campaign_id_param)
        authorize! :read, campaign
        data = Analytics::Aggregator.new(campaign).campaign_analytics(campaign)
        render json: { analytics: data, generatedAt: Time.current.iso8601 }
      end

      private

      def authorize_analytics!
        authorize! :read, :analytics
      end

      def link_id_param
        params[:link_id].presence || params[:id]
      end

      def campaign_id_param
        params[:campaign_id].presence || params[:id]
      end
    end
  end
end
