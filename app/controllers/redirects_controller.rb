# frozen_string_literal: true

class RedirectsController < ApplicationController
  def show
    link = find_link_for_request
    return head :not_found unless link

    destination = link.merged_destination_url(link.redirect_destination_url)
    return head :not_found if destination.blank?

    link.record_click!(request)
    redirect_to destination, allow_other_host: true, status: :found
  end

  private

  def find_link_for_request
    short_code = params[:short_code]
    host = request.host.to_s.downcase
    default_host = ENV.fetch("SHORT_LINK_HOST", "links.blackcollar.io").downcase

    custom_domain = CustomDomain.verified.find_by(domain: host)
    if custom_domain
      Link.find_by(short_code: short_code, custom_domain_id: custom_domain.id)
    elsif host == default_host || Rails.env.test?
      Link.find_by(short_code: short_code, custom_domain_id: nil)
    end
  end
end
