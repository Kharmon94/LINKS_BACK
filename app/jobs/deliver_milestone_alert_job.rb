# frozen_string_literal: true

class DeliverMilestoneAlertJob < ApplicationJob
  queue_as :default

  def perform(entity_type, entity_id)
    entity = case entity_type.to_s
             when "Link" then Link.find_by(id: entity_id)
             when "Campaign" then Campaign.find_by(id: entity_id)
             end
    return unless entity

    MilestoneAlertDelivery.call(entity)
  end
end
