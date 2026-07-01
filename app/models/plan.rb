# frozen_string_literal: true

class Plan < ApplicationRecord
  TIERS = %w[starter growth pro].freeze

  def self.active_price_ids_for_mode
    where(active: true).flat_map { |plan| plan.stripe_price_ids_for_mode.compact }.uniq
  end

  def self.active_price_id_for_mode?(price_id)
    price_id.present? && active_price_ids_for_mode.include?(price_id)
  end

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
      price_ids = [
        plan.stripe_price_id_monthly,
        plan.stripe_price_id_yearly,
        plan.stripe_price_id_monthly_live,
        plan.stripe_price_id_yearly_live
      ].compact
      return plan.tier if price_ids.include?(price_id)
    end
    nil
  end
end
