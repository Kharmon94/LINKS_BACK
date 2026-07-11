# frozen_string_literal: true

class WebPushSender
  class << self
    def send_to!(subscription, title:, body:, url: "/")
      payload = {
        title: title,
        body: body,
        url: url
      }.to_json

      Webpush.payload_send(
        message: payload,
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh,
        auth: subscription.auth,
        vapid: {
          subject: ENV.fetch("VAPID_SUBJECT", "https://links.blackcollar.io"),
          public_key: ENV.fetch("VAPID_PUBLIC_KEY"),
          private_key: ENV.fetch("VAPID_PRIVATE_KEY")
        }
      )
    end
  end
end

