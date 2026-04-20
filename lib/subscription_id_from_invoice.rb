# frozen_string_literal: true

module SubscriptionIdFromInvoice
  module_function

  def call(invoice)
    inv = invoice.is_a?(Hash) ? invoice.with_indifferent_access : invoice
    return inv["subscription"] if inv["subscription"].present?

    inv.dig("parent", "subscription_details", "subscription").presence ||
      inv.dig("lines", "data", 0, "parent", "subscription_item_details", "subscription")
  end
end
