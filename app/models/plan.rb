# frozen_string_literal: true

class Plan < ApplicationRecord
  TIERS = %w[starter growth].freeze

  validates :name, presence: true
  validates :tier, inclusion: { in: TIERS }

  def stripe_price_ids_for_mode
    if StripeMode.live?
      [stripe_price_id_monthly_live.presence || stripe_price_id_monthly,
       stripe_price_id_yearly_live.presence || stripe_price_id_yearly]
    else
      [stripe_price_id_monthly, stripe_price_id_yearly]
    end
  end

  def self.tier_for_price_id(price_id)
    return nil if price_id.blank?

    find_each do |plan|
      monthly, yearly = plan.stripe_price_ids_for_mode
      return plan.tier if [monthly, yearly].compact.include?(price_id)
    end
    nil
  end
end
