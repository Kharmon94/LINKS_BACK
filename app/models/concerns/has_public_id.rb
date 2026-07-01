# frozen_string_literal: true

module HasPublicId
  extend ActiveSupport::Concern

  included do
    before_validation :ensure_public_id, on: :create
    validates :public_id, presence: true, uniqueness: true
  end

  class_methods do
    def find_by_param!(relation, param)
      scope = relation.is_a?(ActiveRecord::Relation) ? relation : all
      param = param.to_s

      record = scope.find_by(public_id: param)
      return record if record

      if param.match?(/\A\d+\z/)
        record = scope.find_by(id: param.to_i)
        return record if record
      end

      raise ActiveRecord::RecordNotFound,
            "Couldn't find #{model_name.name} with public_id or id=#{param}"
    end
  end

  def self.find_by_param!(scope, param)
    model = scope.is_a?(Class) ? scope : scope.klass
    model.find_by_param!(scope, param)
  end

  private

  def ensure_public_id
    return if public_id.present?

    loop do
      candidate = SecureRandom.alphanumeric(12).downcase
      next if self.class.exists?(public_id: candidate)

      self.public_id = candidate
      break
    end
  end
end
