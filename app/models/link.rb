# frozen_string_literal: true

class Link < ApplicationRecord
  include HasPublicId
  include AlertPreferences

  LINK_TYPES = %w[single randomizer].freeze

  belongs_to :user
  belongs_to :workspace, optional: true
  belongs_to :custom_domain, optional: true
  belongs_to :campaign, optional: true
  has_many :pool_entries, class_name: "LinkPoolEntry", dependent: :destroy
  has_many :click_events, dependent: :destroy

  ResolvedRedirect = Struct.new(:url, :pool_entry, keyword_init: true)

  accepts_nested_attributes_for :pool_entries, allow_destroy: true

  validates :destination_url, presence: true, if: :single?
  validates :short_code, presence: true
  validates :link_type, inclusion: { in: LINK_TYPES }
  validate :destination_must_be_http_url, if: :single?
  validate :randomizer_requires_pool, if: :randomizer?
  validate :custom_short_code_format, if: -> { short_code.present? && short_code_changed? }
  validate :short_code_uniqueness_scope

  before_validation :ensure_short_code, on: :create
  before_validation :sync_randomizer_destination

  scope :randomizers, -> { where(link_type: "randomizer") }
  scope :singles, -> { where(link_type: "single") }

  def single?
    link_type == "single"
  end

  def randomizer?
    link_type == "randomizer"
  end

  def pick_pool_entry
    entries = pool_entries.to_a
    return nil if entries.empty?

    total = entries.sum(&:weight)
    roll = rand(total)
    cumulative = 0
    entries.each do |entry|
      cumulative += entry.weight
      return entry if roll < cumulative
    end
    entries.last
  end

  def resolve_redirect
    if randomizer?
      entry = pick_pool_entry
      ResolvedRedirect.new(url: entry&.destination_url, pool_entry: entry)
    else
      ResolvedRedirect.new(url: destination_url, pool_entry: nil)
    end
  end

  def redirect_destination_url
    resolve_redirect.url
  end

  def merged_destination_url(base_url = redirect_destination_url)
    return nil if base_url.blank?

    uri = URI.parse(base_url)
    params = URI.decode_www_form(uri.query || "")
    utm_params = {
      "utm_source" => utm_source,
      "utm_medium" => utm_medium,
      "utm_campaign" => utm_campaign,
      "utm_term" => utm_term,
      "utm_content" => utm_content
    }
    utm_params.each do |key, value|
      next if value.blank?

      params << [key, value] unless params.any? { |k, _| k == key }
    end
    uri.query = URI.encode_www_form(params) if params.any?
    uri.to_s
  rescue URI::InvalidURIError
    base_url
  end

  def record_click!(request, pool_entry: nil, destination_url: nil)
    record_click_from_metadata!(
      ClickMetadata.from_request(request),
      pool_entry: pool_entry,
      destination_url: destination_url
    )
  end

  def record_click_from_metadata!(metadata, pool_entry: nil, destination_url: nil)
    transaction do
      click_events.create!(
        metadata.merge(
          clicked_at: Time.current,
          pool_entry: pool_entry,
          destination_url: destination_url
        )
      )
      increment!(:clicks_count)
    end
  end

  def short_link_host
    custom_domain&.verified? ? custom_domain.domain : ENV.fetch("SHORT_LINK_HOST", "links.blackcollar.io")
  end

  def as_json_for_client(host: nil)
    short_host = (host || short_link_host).to_s.sub(%r{\Ahttps?://}i, "")
    full_short = "https://#{short_host}/#{short_code}"
    {
      id: id.to_s,
      publicId: public_id,
      name: name.presence || "Untitled",
      originalUrl: randomizer? ? "#{pool_entries.size} destinations" : destination_url,
      shortCode: short_code,
      shortUrl: "#{short_host}/#{short_code}",
      fullShortUrl: full_short,
      clicks: clicks_count,
      createdAt: created_at&.iso8601,
      linkType: link_type,
      campaign: campaign ? { id: campaign.id.to_s, publicId: campaign.public_id, name: campaign.name } : nil,
      campaignId: campaign&.public_id,
      workspaceId: workspace&.public_id,
      customDomainId: custom_domain_id&.to_s,
      isRandomizer: randomizer?,
      poolEntries: pool_entries.map { |e| pool_entry_json(e) },
      utmParams: {
        source: utm_source,
        medium: utm_medium,
        campaign: utm_campaign,
        term: utm_term,
        content: utm_content
      }
    }.merge(alert_preferences_as_json)
  end

  def as_json_for_admin
    json = as_json_for_client
    json.merge(
      userId: user.public_id,
      userEmail: user.email
    )
  end

  private

  def pool_entry_json(entry)
    {
      id: entry.id.to_s,
      url: entry.destination_url,
      weight: entry.weight,
      position: entry.position
    }
  end

  def destination_must_be_http_url
    return if UrlValidator.safe_http_url?(destination_url)

    errors.add(:destination_url, "must be a valid http(s) URL")
  end

  def randomizer_requires_pool
    active_entries = pool_entries.reject(&:marked_for_destruction?)
    if active_entries.size < 2
      errors.add(:base, "Randomizer links require at least 2 pool entries")
    end
  end

  def custom_short_code_format
    return if short_code.match?(/\A[a-z0-9_-]+\z/i)

    errors.add(:short_code, "may only contain letters, numbers, hyphens, and underscores")
  end

  def short_code_uniqueness_scope
    return if short_code.blank?

    scope = Link.where(short_code: short_code)
    scope = if custom_domain_id.nil?
              scope.where(custom_domain_id: nil)
            else
              scope.where(custom_domain_id: custom_domain_id)
            end
    scope = scope.where.not(id: id) if persisted?

    errors.add(:short_code, "has already been taken") if scope.exists?
  end

  def ensure_short_code
    return if short_code.present?

    self.short_code = generate_unique_short_code
  end

  def sync_randomizer_destination
    return unless randomizer?

    first = pool_entries.reject(&:marked_for_destruction?).first
    self.destination_url = first.destination_url if first&.destination_url.present?
  end

  def generate_unique_short_code
    loop do
      code = SecureRandom.alphanumeric(6).downcase
      scope = Link.where(short_code: code)
      scope = if custom_domain_id.nil?
                scope.where(custom_domain_id: nil)
              else
                scope.where(custom_domain_id: custom_domain_id)
              end
      break code unless scope.exists?
    end
  end
end
