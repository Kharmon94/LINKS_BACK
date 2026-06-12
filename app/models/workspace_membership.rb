# frozen_string_literal: true

class WorkspaceMembership < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  validates :user_id, uniqueness: { scope: :workspace_id }
end
