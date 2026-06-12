# frozen_string_literal: true

module Api
  module V1
    module Admin
      class UsersController < BaseController
        before_action :set_user, only: %i[show update]

        def index
          authorize! :index, User
          result = ::Admin::UserScope.call(
            q: params[:q],
            role: params[:role],
            page: params[:page],
            per_page: params[:per_page]
          )
          render json: {
            users: result[:users].map(&:as_json_for_admin),
            meta: result[:meta]
          }
        end

        def show
          authorize! :show, @user
          render json: { user: @user.as_json_for_admin(include_recent_links: true) }
        end

        def update
          authorize! :update, @user
          if @user.update(admin_user_params)
            sync_personal_team_membership!(@user) if @user.saved_change_to_role?
            render json: { user: @user.as_json_for_admin(include_recent_links: true) }
          else
            render json: { error: @user.errors.full_messages.to_sentence }, status: :unprocessable_entity
          end
        end

        private

        def set_user
          @user = User.find(params[:id])
        end

        def admin_user_params
          attrs = {}
          if params.key?(:admin)
            attrs[:admin] = ActiveModel::Type::Boolean.new.cast(params[:admin])
          end
          if params.key?(:role) && %w[owner admin member].include?(params[:role].to_s)
            attrs[:role] = params[:role]
          end
          if params.key?(:subscription_tier) || params.key?(:subscriptionTier)
            tier = (params[:subscription_tier] || params[:subscriptionTier]).to_s
            attrs[:subscription_tier] = tier if User::TIER_LIMITS.key?(tier)
          end
          attrs
        end

        def sync_personal_team_membership!(user)
          membership = user.team_memberships.joins(:team).find_by(teams: { personal: true })
          return unless membership
          return if membership.role == user.role

          membership.update!(role: user.role)
        end
      end
    end
  end
end
