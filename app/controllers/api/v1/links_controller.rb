# frozen_string_literal: true

module Api
  module V1
    class LinksController < BaseController
      load_and_authorize_resource through: :current_user, except: [:index]
      before_action :set_user_links, only: [:index]

      def index
        render json: { links: @links.order(created_at: :desc).map(&:as_json_for_client) }
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

        @link = current_user.links.build(link_params)
        if @link.save
          render json: { link: @link.as_json_for_client }, status: :created
        else
          render json: { error: @link.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def update
        if @link.update(link_params)
          render json: { link: @link.as_json_for_client }
        else
          render json: { error: @link.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def destroy
        @link.destroy!
        head :no_content
      end

      private

      def set_user_links
        @links = current_user.links
      end

      def link_params
        p = params[:link].presence || params
        p.permit(:destination_url, :name)
      end
    end
  end
end
