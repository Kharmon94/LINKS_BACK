# frozen_string_literal: true

module Api
  module V1
    module Admin
      class FeatureFlagsController < BaseController
        before_action :set_feature_flag, only: :update

        def index
          authorize! :index, FeatureFlag
          flags = FeatureFlag.ordered
          render json: { featureFlags: flags.map(&:as_json_for_admin) }
        end

        def update
          authorize! :update, @feature_flag
          if @feature_flag.update(feature_flag_params)
            render json: { featureFlag: @feature_flag.as_json_for_admin }
          else
            render json: { error: @feature_flag.errors.full_messages.to_sentence }, status: :unprocessable_entity
          end
        end

        private

        def set_feature_flag
          @feature_flag = FeatureFlag.find_by!(key: params[:key])
        end

        def feature_flag_params
          p = params[:feature_flag].presence || params
          attrs = p.permit(:enabled)
          attrs[:enabled] = ActiveModel::Type::Boolean.new.cast(attrs[:enabled]) if attrs.key?(:enabled)
          attrs
        end
      end
    end
  end
end
