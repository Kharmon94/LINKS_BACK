# frozen_string_literal: true

class WebPushSender
  class << self
    def send_to!(subscription, title:, body:, url: "/")
      payload = {
        title: title,
        body: body,
        url: url
      }.to_json

      WebPush.payload_send(
        message: payload,
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh,
        auth: subscription.auth,
        vapid: vapid_options
      )
    end

    # VAPID keys must be base64url strings (not OpenSSL::PKey objects).
    # The web-push gem loads them in an OpenSSL 3–safe way.
    def vapid_options
      {
        subject: ENV.fetch("VAPID_SUBJECT", "https://links.blackcollar.io"),
        public_key: ENV.fetch("VAPID_PUBLIC_KEY"),
        private_key: ENV.fetch("VAPID_PRIVATE_KEY")
      }
    end
  end
end

