# frozen_string_literal: true

class UserFeatureFlagOverride < ApplicationRecord
  belongs_to :user

  validates :feature_flag_key, presence: true, uniqueness: { scope: :user_id }
  validates :enabled, inclusion: { in: [true, false] }
end
