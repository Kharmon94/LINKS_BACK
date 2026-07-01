# frozen_string_literal: true

if Rails.env.production? && ENV["RESEND_API_KEY"].blank?
  Rails.application.config.after_initialize do
    Rails.logger.warn(
      "[mail] RESEND_API_KEY is not set; outbound email delivery will fail in production"
    )
  end
end
