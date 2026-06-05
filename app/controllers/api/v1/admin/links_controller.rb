# frozen_string_literal: true

module Api
  module V1
    module Admin
      class LinksController < BaseController
        before_action :set_link, only: %i[show destroy]

        def index
          authorize! :index, Link
          result = link_scope
          render json: {
            links: result[:links].map(&:as_json_for_admin),
            meta: result[:meta]
          }
        end

        def show
          authorize! :show, @link
          render json: { link: @link.as_json_for_admin }
        end

        def destroy
          authorize! :destroy, @link
          @link.destroy!
          head :no_content
        end

        private

        def set_link
          @link = Link.includes(:user).find(params[:id])
        end

        def link_scope
          per_page = params[:per_page].to_i
          per_page = 50 if per_page <= 0
          per_page = [per_page, 200].min
          page = [params[:page].to_i, 1].max

          scope = Link.includes(:user).order(created_at: :desc)
          if params[:user_id].present?
            scope = scope.where(user_id: params[:user_id])
          end
          if params[:q].present?
            term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.downcase)}%"
            scope = scope.where(
              "lower(short_code) LIKE ? OR lower(name) LIKE ? OR lower(destination_url) LIKE ?",
              term, term, term
            )
          end

          total = scope.count
          links = scope.offset((page - 1) * per_page).limit(per_page)

          {
            links: links,
            meta: {
              page: page,
              perPage: per_page,
              total: total,
              q: params[:q].presence,
              userId: params[:user_id].presence
            }.compact
          }
        end
      end
    end
  end
end
