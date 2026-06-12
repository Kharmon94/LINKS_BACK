# frozen_string_literal: true

class LinkPoolEntry < ApplicationRecord
  belongs_to :link

  validates :destination_url, presence: true
  validates :weight, numericality: { greater_than: 0 }
  validate :destination_must_be_http_url

  default_scope { order(:position, :id) }

  private

  def destination_must_be_http_url
    return if UrlValidator.safe_http_url?(destination_url)

    errors.add(:destination_url, "must be a valid http(s) URL")
  end
end
