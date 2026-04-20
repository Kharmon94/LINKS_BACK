# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Contact", type: :request do
  it "accepts contact and enqueues mail" do
    expect do
      post "/api/v1/contact",
           params: { name: "A", email: "a@example.com", message: "Hello" },
           as: :json
    end.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    expect(response).to have_http_status(:created)
  end

  it "returns 422 when message missing" do
    post "/api/v1/contact", params: { email: "a@example.com" }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
