# frozen_string_literal: true

require "rails_helper"

RSpec.describe ClickMetadata do
  def build_request(env = {})
    env = {
      "REMOTE_ADDR" => "203.0.113.50",
      "HTTP_USER_AGENT" => "Mozilla/5.0",
      "rack.input" => StringIO.new
    }.merge(env)
    ActionDispatch::Request.new(Rails.application.env_config.merge(env))
  end

  describe ".from_request" do
    it "uses CDN country headers before IP lookup" do
      request = build_request("HTTP_CF_IPCOUNTRY" => "US")

      allow(described_class).to receive(:lookup_geo).and_return(%w[Canada Toronto])

      metadata = described_class.from_request(request)

      expect(metadata[:country]).to eq("United States")
      expect(metadata[:city]).to be_nil
      expect(described_class).not_to have_received(:lookup_geo)
    end

    it "checks CloudFront and Vercel CDN headers" do
      request = build_request("HTTP_CLOUDFRONT_VIEWER_COUNTRY" => "DE")
      metadata = described_class.from_request(request)
      expect(metadata[:country]).to eq("Germany")

      request = build_request("HTTP_X_VERCEL_IP_COUNTRY" => "FR")
      metadata = described_class.from_request(request)
      expect(metadata[:country]).to eq("France")
    end

    it "maps any ISO country code from CDN headers to a full name" do
      request = build_request("HTTP_CF_IPCOUNTRY" => "NL")
      metadata = described_class.from_request(request)
      expect(metadata[:country]).to eq("Netherlands")
    end

    it "skips geo lookup for private IPs" do
      request = build_request("REMOTE_ADDR" => "127.0.0.1")

      allow(described_class).to receive(:lookup_geo)

      metadata = described_class.from_request(request)

      expect(metadata[:country]).to be_nil
      expect(metadata[:city]).to be_nil
      expect(described_class).not_to have_received(:lookup_geo)
    end

    it "falls back to geocoder lookup for public IPs" do
      request = build_request("REMOTE_ADDR" => "203.0.113.50")

      allow(described_class).to receive(:lookup_geo).and_return(["United States", "Chicago"])

      metadata = described_class.from_request(request)

      expect(metadata[:country]).to eq("United States")
      expect(metadata[:city]).to eq("Chicago")
    end

    it "returns nil geo on lookup failure without raising" do
      request = build_request("REMOTE_ADDR" => "203.0.113.50")

      allow(described_class).to receive(:lookup_geo).and_raise(StandardError, "lookup failed")

      metadata = nil
      expect { metadata = described_class.from_request(request) }.not_to raise_error
      expect(metadata[:country]).to be_nil
      expect(metadata[:city]).to be_nil
    end
  end

  describe ".private_ip?" do
    it "treats loopback and RFC1918 addresses as private" do
      expect(described_class.private_ip?("127.0.0.1")).to be true
      expect(described_class.private_ip?("10.0.0.1")).to be true
      expect(described_class.private_ip?("203.0.113.50")).to be false
    end
  end
end
