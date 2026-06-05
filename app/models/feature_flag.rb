# frozen_string_literal: true

class FeatureFlag < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :category, presence: true

  scope :ordered, -> { order(:category, :key) }

  def self.enabled?(key)
    find_by(key: key.to_s)&.enabled? || false
  end

  def as_json_for_admin
    {
      key: key,
      enabled: enabled,
      description: description,
      category: category,
      updatedAt: updated_at&.iso8601
    }
  end
end
