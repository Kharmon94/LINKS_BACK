# frozen_string_literal: true

require "ipaddr"
require "countries/global"

class ClickMetadata
  DEVICE_COLORS = {
    "Mobile" => "#4285F4",
    "Desktop" => "#34A853",
    "Tablet" => "#FBBC05"
  }.freeze

  CDN_COUNTRY_HEADERS = {
    "HTTP_CF_IPCOUNTRY" => "CF-IPCountry",
    "HTTP_CLOUDFRONT_VIEWER_COUNTRY" => "CloudFront-Viewer-Country",
    "HTTP_X_VERCEL_IP_COUNTRY" => "X-Vercel-IP-Country"
  }.freeze

  def self.from_request(request)
    ua = request.user_agent.to_s
    ip = request.remote_ip.to_s
    country, city = resolve_geo(request, ip)

    {
      referrer: request.referer.presence,
      user_agent: ua,
      device_type: parse_device(ua),
      browser: parse_browser(ua),
      os: parse_os(ua),
      country: country,
      city: city,
      ip_hash: Digest::SHA256.hexdigest(ip)[0, 16]
    }
  end

  def self.resolve_geo(request, ip)
    cdn_country = country_from_cdn_headers(request)
    return [cdn_country, nil] if cdn_country.present?

    return [nil, nil] if private_ip?(ip)

    lookup_geo(ip)
  rescue StandardError
    [nil, nil]
  end

  def self.country_from_cdn_headers(request)
    CDN_COUNTRY_HEADERS.each do |rack_key, _|
      code = request.env[rack_key].to_s.strip.upcase
      next if code.blank? || code == "XX" || code == "T1"

      return iso_country_name(code)
    end
    nil
  end

  def self.iso_country_name(code)
    normalized = code.to_s.strip.upcase
    return normalized if normalized.blank?

    country = ISO3166::Country[normalized]
    country&.common_name || country&.iso_short_name || normalized
  end

  def self.lookup_geo(ip)
    return [nil, nil] unless geo_lookup_enabled?

    result = Geocoder.search(ip).first
    return [nil, nil] unless result

    country = result.country.presence || iso_country_name(result.country_code.to_s.upcase)
    city = result.city.presence
    [country, city]
  rescue StandardError
    [nil, nil]
  end

  def self.geo_lookup_enabled?
    geoip_path = ENV["GEOIP_DB_PATH"].presence || Rails.root.join("vendor", "GeoLite2-City.mmdb").to_s
    File.exist?(geoip_path)
  end

  def self.private_ip?(ip)
    return true if ip.blank?

    addr = IPAddr.new(ip)
    addr.private? || addr.loopback?
  rescue IPAddr::InvalidAddressError
    true
  end

  def self.parse_device(ua)
    return "Desktop" if ua.blank?

    if ua.match?(/iPad|Tablet|Kindle|PlayBook/i)
      "Tablet"
    elsif ua.match?(/Mobile|Android|iPhone|iPod|webOS|BlackBerry|Opera Mini/i)
      "Mobile"
    else
      "Desktop"
    end
  end

  def self.parse_browser(ua)
    return "Unknown" if ua.blank?

    case ua
    when /Edg\//i then "Edge"
    when /Chrome\//i then "Chrome"
    when /Firefox\//i then "Firefox"
    when /Safari\//i then "Safari"
    else "Other"
    end
  end

  def self.parse_os(ua)
    return "Unknown" if ua.blank?

    case ua
    when /Windows/i then "Windows"
    when /Mac OS X|Macintosh/i then "macOS"
    when /Android/i then "Android"
    when /iPhone|iPad|iPod/i then "iOS"
    when /Linux/i then "Linux"
    else "Other"
    end
  end
end
