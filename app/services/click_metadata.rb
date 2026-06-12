# frozen_string_literal: true

class ClickMetadata
  DEVICE_COLORS = {
    "Mobile" => "#4285F4",
    "Desktop" => "#34A853",
    "Tablet" => "#FBBC05"
  }.freeze

  def self.from_request(request)
    ua = request.user_agent.to_s
    {
      referrer: request.referer.presence,
      user_agent: ua,
      device_type: parse_device(ua),
      browser: parse_browser(ua),
      os: parse_os(ua),
      country: nil,
      city: nil,
      ip_hash: Digest::SHA256.hexdigest(request.remote_ip.to_s)[0, 16]
    }
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
