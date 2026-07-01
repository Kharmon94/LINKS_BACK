# frozen_string_literal: true

class BillingEvent < ApplicationRecord
  belongs_to :user

  validates :event_type, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def as_json_for_admin
    {
      id: id.to_s,
      userId: user.public_id,
      email: user.email,
      eventType: event_type,
      tier: tier,
      amountCents: amount_cents,
      amountFormatted: amount_cents ? self.class.format_money(amount_cents) : nil,
      stripeCustomerId: stripe_customer_id,
      payloadSummary: payload_summary,
      createdAt: created_at&.iso8601
    }
  end

  def self.record_from_stripe!(event, user:, tier: nil, amount_cents: nil)
    create!(
      user: user,
      stripe_event_id: event.id,
      event_type: event.type,
      tier: tier || user.subscription_tier,
      amount_cents: amount_cents,
      stripe_customer_id: extract_customer_id(event, user),
      payload_summary: summarize(event)
    )
  rescue ActiveRecord::RecordNotUnique
    find_by(stripe_event_id: event.id)
  end

  def self.extract_customer_id(event, user)
    obj = event.data.object
    customer = obj.respond_to?(:customer) ? obj.customer : nil
    customer.presence || user.stripe_customer_id
  end

  def self.summarize(event)
    obj = event.data.object
    case event.type
    when "checkout.session.completed"
      "Checkout completed"
    when "customer.subscription.created", "customer.subscription.updated", "customer.subscription.deleted"
      status = obj.respond_to?(:status) ? obj.status : nil
      [event.type.split(".").last, status].compact.join(" — ")
    when "invoice.paid", "invoice.payment_failed"
      total = obj.respond_to?(:amount_paid) ? obj.amount_paid : obj.amount_due
      cents = total.to_i
      "$#{'%.2f' % (cents / 100.0)}"
    else
      event.type
    end
  end

  def self.format_money(cents)
    "$#{'%.2f' % (cents / 100.0)}"
  end

  private_class_method :extract_customer_id, :summarize
end
