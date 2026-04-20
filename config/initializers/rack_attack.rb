# frozen_string_literal: true

Rails.application.config.middleware.use Rack::Attack

Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

Rack::Attack.throttle("public_posts/ip", limit: 30, period: 1.minute) do |req|
  if req.post? && req.path.match?(%r{\A/api/(links/create-with-account|auth/magic-link|v1/contact)})
    req.ip
  end
end

ActiveSupport::Notifications.subscribe("rack.attack") do |_name, _start, _finish, _request_id, payload|
  req = payload[:request]
  Rails.logger.warn("[Rack::Attack] #{req.env['rack.attack.match_type']} #{req.ip} #{req.path}") if req.env["rack.attack.match_type"]
end
