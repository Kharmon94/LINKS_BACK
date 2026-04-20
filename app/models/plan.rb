# frozen_string_literal: true

class Plan < ApplicationRecord
  validates :name, presence: true
end
