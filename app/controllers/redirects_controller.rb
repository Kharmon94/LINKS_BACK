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

    if (custom_domain = CustomDomain.verified.find_by(domain: host))
      return Link.find_by(short_code: short_code, custom_domain_id: custom_domain.id)
    end

    # Default short links (no custom domain on this host).
    # short_code is globally unique; custom-domain links use custom_domain_id on the row.
    Link.find_by(short_code: short_code, custom_domain_id: nil)
  end
end
