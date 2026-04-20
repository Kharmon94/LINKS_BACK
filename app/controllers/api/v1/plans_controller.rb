# frozen_string_literal: true

module Api
  module V1
    class PlansController < ApplicationController
      def index
        plans = Plan.where(active: true).order(:name)
        render json: {
          plans: plans.map { |p|
            {
              id: p.id,
              name: p.name,
              stripe_price_id_monthly: p.stripe_price_id_monthly,
              stripe_price_id_yearly: p.stripe_price_id_yearly
            }
          }
        }
      end
    end
  end
end
