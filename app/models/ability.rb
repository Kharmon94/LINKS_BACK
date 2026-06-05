# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    Permissions::Rules.new(user).apply_to(self)
  end
end
