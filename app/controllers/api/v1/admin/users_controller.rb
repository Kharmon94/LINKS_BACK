# frozen_string_literal: true

module Api
  module V1
    module Admin
      class UsersController < BaseController
        before_action :require_admin!

        def index
          users = User.order(created_at: :desc).limit(200)
          render json: { users: users.map(&:as_json_for_client) }
        end

        def show
          user = User.find(params[:id])
          render json: { user: user.as_json_for_client }
        end

        def update
          user = User.find(params[:id])
          if params.key?(:admin)
            user.update!(admin: ActiveModel::Type::Boolean.new.cast(params[:admin]))
          end
          render json: { user: user.as_json_for_client }
        end

        private

        def require_admin!
          head :forbidden unless current_user.admin?
        end
      end
    end
  end
end
