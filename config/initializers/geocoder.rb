# frozen_string_literal: true

geoip_path = ENV["GEOIP_DB_PATH"].presence || Rails.root.join("vendor", "GeoLite2-City.mmdb").to_s

if File.exist?(geoip_path)
  Geocoder.configure(
    ip_lookup: :geoip2,
    geoip2: { file: geoip_path },
    timeout: 2
  )
end
