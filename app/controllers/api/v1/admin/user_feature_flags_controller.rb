# frozen_string_literal: true

module Api
  module V1
    module Admin
      class UserFeatureFlagsController < BaseController
        before_action :set_user
        before_action :set_feature_flag, only: :update

        def index
          authorize! :index, FeatureFlag
          render json: { userFeatureFlags: FeatureFlag.ordered.map { |flag| flag_json(flag) } }
        end

        def update
          authorize! :update, FeatureFlag
          apply_override!
          render json: { userFeatureFlag: flag_json(@feature_flag) }
        end

        private

        def set_user
          @user = HasPublicId.find_by_param!(User, params[:user_id])
        end

        def set_feature_flag
          @feature_flag = FeatureFlag.find_by!(key: params[:key])
        end

        def apply_override!
          if params.key?(:enabled) && params[:enabled].nil?
            @user.feature_flag_overrides.where(feature_flag_key: @feature_flag.key).destroy_all
          elsif params.key?(:enabled)
            enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])
            override = @user.feature_flag_overrides.find_or_initialize_by(feature_flag_key: @feature_flag.key)
            override.enabled = enabled
            override.save!
          else
            raise ActionController::ParameterMissing, :enabled
          end
          @user.clear_feature_flag_overrides_cache!
        end

        def flag_json(flag)
          override = @user.feature_flag_overrides_by_key[flag.key]
          {
            key: flag.key,
            globalEnabled: flag.enabled?,
            override: override&.enabled,
            effectiveEnabled: FeatureFlag.enabled_for?(@user, flag.key)
          }
        end
      end
    end
  end
end
