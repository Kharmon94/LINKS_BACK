# frozen_string_literal: true

module Api
  module V1
    class LinksController < BaseController
      include WorkspaceScoping

      before_action :set_user_links, only: [:index]
      before_action :set_link, only: %i[show update destroy clicks]

      def index
        page = [params[:page].to_i, 1].max
        per_page = params[:per_page].presence&.to_i || 25
        per_page = per_page.clamp(1, 100)
        scope = filtered_links.order(created_at: :desc)
        total = scope.count
        records = scope.offset((page - 1) * per_page).limit(per_page)

        render json: {
          links: records.map(&:as_json_for_client),
          meta: {
            page: page,
            perPage: per_page,
            total: total,
            q: params[:q].presence,
            linkType: params[:link_type].presence,
            campaignId: params[:campaign_id].presence,
            workspaceId: params[:workspace_id].presence
          }
        }
      end

      def show
        authorize! :show, @link
        render json: { link: @link.as_json_for_client }
      end

      def create
        if current_user.at_link_limit?
          return render json: {
            error: "You've reached your tier limit. Upgrade to create more links.",
            upgrade_url: "/pricing"
          }, status: :forbidden
        end

        if randomizer_requested? && !FeatureFlag.enabled_for?(current_user, :randomizer)
          return render json: { error: "Randomizer feature is not enabled" }, status: :forbidden
        end

        @link = current_user.links.build(link_params)
        return unless assign_workspace_and_domain!(@link)

        authorize! :create, @link
        if @link.save
          render json: { link: @link.as_json_for_client }, status: :created
        else
          render json: { error: @link.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def update
        authorize! :update, @link
        if randomizer_requested? && !FeatureFlag.enabled_for?(current_user, :randomizer)
          return render json: { error: "Randomizer feature is not enabled" }, status: :forbidden
        end

        @link.assign_attributes(link_params)
        return unless assign_workspace_and_domain!(@link)

        if @link.save
          render json: { link: @link.as_json_for_client }
        else
          render json: { error: @link.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize! :destroy, @link
        @link.destroy!
        head :no_content
      end

      def clicks
        authorize! :show, @link
        page = [params[:page].to_i, 1].max
        per_page = params[:per_page].presence&.to_i || 25
        per_page = per_page.clamp(1, 100)
        events = @link.click_events.order(clicked_at: :desc)
        total = events.count
        paginated = events.offset((page - 1) * per_page).limit(per_page)

        render json: {
          clicks: paginated.map(&:as_json_for_client),
          meta: { page: page, perPage: per_page, total: total }
        }
      end

      private

      def filtered_links
        scope = @links.includes(:campaign, :pool_entries, :workspace)
        if params[:campaign_id].present?
          campaign = HasPublicId.find_by_param!(current_user.campaigns, params[:campaign_id])
          scope = scope.where(campaign_id: campaign.id)
        end
        scope = scope.where(link_type: params[:link_type]) if params[:link_type].present?
        if params[:workspace_id].present?
          workspace = HasPublicId.find_by_param!(current_user.accessible_workspaces, params[:workspace_id])
          scope = scope.where(workspace_id: workspace.id)
        end
        if params[:q].present?
          term = "%#{params[:q].to_s.downcase}%"
          scope = scope.where(
            "LOWER(name) LIKE :term OR LOWER(short_code) LIKE :term OR LOWER(destination_url) LIKE :term",
            term: term
          )
        end
        scope
      end

      def set_user_links
        @links = scoped_links
      end

      def set_link
        @link = HasPublicId.find_by_param!(scoped_links, params[:id])
      end

      def randomizer_requested?
        type = params.dig(:link, :link_type) || params[:link_type]
        type.to_s == "randomizer" || params.dig(:link, :pool_entries_attributes).present?
      end

      def assign_workspace_and_domain!(link)
        current_user.assign_default_workspace!(link)

        billing_account = current_user.billing_account

        return true unless custom_domain_id_param_present?

        unless CustomDomain.allowed_for?(current_user)
          render json: { error: "Custom domains are not available on your plan" }, status: :forbidden
          return false
        end

        unless Permissions::Rules::CAMPAIGN_MANAGER_ROLES.include?(current_user.team_role)
          render json: { error: "Only team owners and admins can assign custom domains" }, status: :forbidden
          return false
        end

        if link.custom_domain_id.present?
          domain = resolve_custom_domain_for_link(billing_account, link.custom_domain_id)
          link.custom_domain_id = domain&.id
        else
          link.custom_domain_id = nil
        end

        true
      end

      def custom_domain_id_param_present?
        link_params_source.key?(:custom_domain_id)
      end

      def resolve_custom_domain_for_link(billing_account, domain_id)
        billing_account.custom_domains.verified.find_by(id: domain_id)
      end

      def link_params_source
        params[:link].presence || params
      end

      def link_params
        p = params[:link].presence || params
        permitted = p.permit(
          :destination_url, :name, :short_code, :link_type, :campaign_id,
          :workspace_id, :custom_domain_id,
          :push_alerts_enabled, :email_alerts_enabled,
          :utm_source, :utm_medium, :utm_campaign, :utm_term, :utm_content,
          pool_entries_attributes: %i[id destination_url weight position _destroy]
        )
        resolve_link_foreign_keys!(permitted)
        permitted
      end

      def resolve_link_foreign_keys!(permitted)
        if permitted.key?(:campaign_id) && permitted[:campaign_id].present?
          campaign = HasPublicId.find_by_param!(current_user.campaigns, permitted[:campaign_id])
          permitted[:campaign_id] = campaign.id
        end
        if permitted.key?(:workspace_id) && permitted[:workspace_id].present?
          workspace = HasPublicId.find_by_param!(current_user.accessible_workspaces, permitted[:workspace_id])
          permitted[:workspace_id] = workspace.id
        end
      end
    end
  end
end
