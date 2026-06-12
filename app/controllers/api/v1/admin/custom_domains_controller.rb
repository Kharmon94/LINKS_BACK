# frozen_string_literal: true

module Api
  module V1
    module Admin
      class CustomDomainsController < BaseController
        before_action :set_domain, only: :destroy

        def index
          authorize! :read, :admin_custom_domains
          result = paginated_scope(CustomDomain.includes(:user).order(created_at: :desc))
          render json: {
            customDomains: result[:records].map { |d| domain_json(d) },
            meta: result[:meta]
          }
        end

        def destroy
          authorize! :destroy, :admin_custom_domains
          @domain.destroy!
          head :no_content
        end

        private

        def set_domain
          @domain = CustomDomain.find(params[:id])
        end

        def domain_json(domain)
          {
            id: domain.id.to_s,
            domain: domain.domain,
            status: domain.status,
            userId: domain.user_id.to_s,
            userEmail: domain.user.email,
            isDefault: domain.is_default,
            createdAt: domain.created_at&.iso8601
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
              "lower(custom_domains.domain) LIKE ? OR lower(users.email) LIKE ?",
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
