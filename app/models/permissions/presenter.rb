# frozen_string_literal: true

module Permissions
  class Presenter
    def self.for(user)
      new(user).as_json
    end

    def initialize(user)
      @rules = Rules.new(user)
    end

    def as_json
      {
        permissions: @rules.permissions_hash,
        limits: @rules.limits_hash
      }
    end
  end
end
