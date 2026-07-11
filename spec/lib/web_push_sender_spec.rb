# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebPushSender do
  let(:subscription) do
    instance_double(
      WebPushSubscription,
      endpoint: "https://push.example/endpoint",
      p256dh: "p256dh-key",
      auth: "auth-key"
    )
  end

  def with_vapid_env(subject: "https://links.blackcollar.io", public_key: "test-public", private_key: "test-private")
    keys = %w[VAPID_SUBJECT VAPID_PUBLIC_KEY VAPID_PRIVATE_KEY]
    original = keys.index_with { |k| ENV[k] }
    ENV["VAPID_SUBJECT"] = subject
    ENV["VAPID_PUBLIC_KEY"] = public_key
    ENV["VAPID_PRIVATE_KEY"] = private_key
    yield
  ensure
    keys.each do |key|
      original[key].nil? ? ENV.delete(key) : ENV[key] = original[key]
    end
  end

  describe ".vapid_options" do
    it "returns VAPID keys as strings from ENV (OpenSSL 3–safe for web-push)" do
      with_vapid_env(subject: "mailto:ops@example.com", public_key: "public-key-string", private_key: "private-key-string") do
        options = described_class.vapid_options

        expect(options).to eq(
          subject: "mailto:ops@example.com",
          public_key: "public-key-string",
          private_key: "private-key-string"
        )
        expect(options[:public_key]).to be_a(String)
        expect(options[:private_key]).to be_a(String)
      end
    end

    it "defaults subject when VAPID_SUBJECT is unset" do
      with_vapid_env(public_key: "pub", private_key: "priv") do
        ENV.delete("VAPID_SUBJECT")
        expect(described_class.vapid_options[:subject]).to eq("https://links.blackcollar.io")
      end
    end
  end

  describe ".send_to!" do
    it "sends via WebPush with string VAPID options and JSON payload" do
      with_vapid_env do
        allow(WebPush).to receive(:payload_send)

        described_class.send_to!(
          subscription,
          title: "Links",
          body: "Hello",
          url: "/dashboard"
        )

        expect(WebPush).to have_received(:payload_send).with(
          message: { title: "Links", body: "Hello", url: "/dashboard" }.to_json,
          endpoint: "https://push.example/endpoint",
          p256dh: "p256dh-key",
          auth: "auth-key",
          vapid: {
            subject: "https://links.blackcollar.io",
            public_key: "test-public",
            private_key: "test-private"
          }
        )
      end
    end
  end

  describe "OpenSSL 3 VAPID key loading" do
    it "loads base64url VAPID keys without mutating OpenSSL pkeys" do
      key = WebPush.generate_key

      expect do
        loaded = WebPush::VapidKey.from_keys(key.public_key, key.private_key)
        expect(loaded.public_key).to eq(key.public_key)
        expect(loaded.private_key).to eq(key.private_key)
      end.not_to raise_error
    end
  end
end
