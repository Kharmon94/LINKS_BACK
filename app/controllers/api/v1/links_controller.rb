# frozen_string_literal: true

module Api
  module V1
    class LinksController < BaseController
      load_and_authorize_resource through: :current_user, only: %i[show create update destroy]
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
        render json: { link: @link.as_json_for_client }
      end

      def create
        if current_user.at_link_limit?
          return render json: {
            error: "You've reached your tier limit. Upgrade to create more links.",
            upgrade_url: "/pricing"
          }, status: :forbidden
        end

        if randomizer_requested? && !FeatureFlag.enabled?(:randomizer)
          return render json: { error: "Randomizer feature is not enabled" }, status: :forbidden
        end

        @link = current_user.links.build(link_params)
        assign_workspace_and_domain!(@link)
        if @link.save
          render json: { link: @link.as_json_for_client }, status: :created
        else
          render json: { error: @link.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def update
        if randomizer_requested? && !FeatureFlag.enabled?(:randomizer)
          return render json: { error: "Randomizer feature is not enabled" }, status: :forbidden
        end

        @link.assign_attributes(link_params)
        assign_workspace_and_domain!(@link)
        if @link.save
          render json: { link: @link.as_json_for_client }
        else
          render json: { error: @link.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def destroy
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
        scope = @links.includes(:campaign, :pool_entries)
        scope = scope.where(campaign_id: params[:campaign_id]) if params[:campaign_id].present?
        scope = scope.where(link_type: params[:link_type]) if params[:link_type].present?
        scope = scope.where(workspace_id: params[:workspace_id]) if params[:workspace_id].present?
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
        @links = current_user.links
      end

      def set_link
        @link = current_user.links.find(params[:id])
      end

      def randomizer_requested?
        type = params.dig(:link, :link_type) || params[:link_type]
        type.to_s == "randomizer" || params.dig(:link, :pool_entries_attributes).present?
      end

      def assign_workspace_and_domain!(link)
        if FeatureFlag.enabled?(:workspaces)
          workspace = if link.workspace_id.present?
                        current_user.accessible_workspaces.find_by(id: link.workspace_id)
                      else
                        current_user.active_workspace || current_user.accessible_workspaces.first
                      end
          link.workspace = workspace if workspace
        end

        billing_account = current_user.billing_account

        if custom_domain_id_param_present?
          if link.custom_domain_id.present?
            domain = resolve_custom_domain_for_link(billing_account, link.custom_domain_id)
            link.custom_domain_id = domain&.id
          else
            link.custom_domain_id = nil
          end
        elsif link.new_record?
          default_domain = billing_account.custom_domains.verified.find_by(is_default: true)
          link.custom_domain_id = default_domain&.id
        end
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
        p.permit(
          :destination_url, :name, :short_code, :link_type, :campaign_id,
          :workspace_id, :custom_domain_id,
          :utm_source, :utm_medium, :utm_campaign, :utm_term, :utm_content,
          pool_entries_attributes: %i[id destination_url weight position _destroy]
        )
      end
    end
  end
end
