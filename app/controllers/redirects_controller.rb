# frozen_string_literal: true

class RedirectsController < ApplicationController
  def show
    link = find_link_for_request
    return head :not_found unless link

    resolved = link.resolve_redirect
    destination = link.merged_destination_url(resolved.url)
    return head :not_found if destination.blank?

    enqueue_click_record(link, resolved, destination)
    redirect_to destination, allow_other_host: true, status: :found
  end

  private

  def find_link_for_request
    short_code = params[:short_code]
    host = request.host.to_s.downcase

    unless skip_custom_domain_lookup?(host)
      custom_domain = CustomDomain.verified.find_by(domain: host)
      if custom_domain
        link = Link.includes(:pool_entries).find_by(short_code: short_code, custom_domain_id: custom_domain.id)
        return link if link
      end
    end

    Link.includes(:pool_entries).find_by(short_code: short_code, custom_domain_id: nil)
  end

  def skip_custom_domain_lookup?(host)
    default_host = ENV.fetch("SHORT_LINK_HOST", "links.blackcollar.io").to_s.downcase
    return true if host == default_host

    api_host = ENV["API_HOST"].to_s.downcase
    api_host.present? && host == api_host
  end

  def enqueue_click_record(link, resolved, destination)
    metadata = ClickMetadata.from_request(request)
    pool_entry_id = resolved.pool_entry&.id

    if async_click_recording?
      RecordClickJob.perform_later(
        link.id,
        metadata,
        pool_entry_id: pool_entry_id,
        destination_url: destination
      )
    else
      link.record_click_from_metadata!(
        metadata,
        pool_entry: resolved.pool_entry,
        destination_url: destination
      )
    end
  end

  def async_click_recording?
    ENV["REDIRECT_ASYNC_CLICKS"] == "true"
  end
end
