# frozen_string_literal: true

module Api
  module V1
    module Admin
      class CampaignsController < BaseController
        before_action :set_campaign, only: :destroy

        def index
          authorize! :read, :admin_campaigns
          result = paginated_scope(Campaign.includes(:user).order(created_at: :desc))
          render json: {
            campaigns: result[:records].map { |c| campaign_json(c) },
            meta: result[:meta]
          }
        end

        def destroy
          authorize! :destroy, :admin_campaigns
          @campaign.destroy!
          head :no_content
        end

        private

        def set_campaign
          @campaign = Campaign.find(params[:id])
        end

        def campaign_json(campaign)
          {
            id: campaign.id.to_s,
            name: campaign.name,
            userId: campaign.user_id.to_s,
            userEmail: campaign.user.email,
            linksCount: campaign.links.count,
            createdAt: campaign.created_at&.iso8601
          }
        end

        def paginated_scope(scope)
          per_page = params[:per_page].to_i
          per_page = 50 if per_page <= 0
          per_page = [per_page, 200].min
          page = [params[:page].to_i, 1].max

          if params[:q].present?
            term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.downcase)}%"
            scope = scope.joins(:user).where(
              "lower(campaigns.name) LIKE ? OR lower(users.email) LIKE ?",
              term, term
            )
          end

          total = scope.count
          records = scope.offset((page - 1) * per_page).limit(per_page)
          {
            records: records,
            meta: { page: page, perPage: per_page, total: total, q: params[:q].presence }.compact
          }
        end
      end
    end
  end
end
