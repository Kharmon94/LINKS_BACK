# frozen_string_literal: true

class RedirectsController < ApplicationController
  def show
    if ReservedShortLinkSlugs.include?(params[:short_code])
      return redirect_to_frontend_app_route
    end

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

    if platform_redirect_host?(host)
      return find_platform_link(short_code)
    end

    custom_domain = CustomDomain.verified.find_by(domain: host)
    return nil unless custom_domain

    Link.includes(:pool_entries).find_by(short_code: short_code, custom_domain_id: custom_domain.id)
  end

  def find_platform_link(short_code)
    link = Link.includes(:pool_entries).find_by(short_code: short_code, custom_domain_id: nil)
    return link if link

    # Links auto-assigned a default custom domain still share platform short URLs in emails/UI.
    Link.includes(:pool_entries, :custom_domain)
        .joins(:custom_domain)
        .merge(CustomDomain.verified.where(is_default: true))
        .find_by(short_code: short_code)
  end

  def platform_redirect_host?(host)
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

  def redirect_to_frontend_app_route
    origin = frontend_origin
    return head :not_found if origin.blank?

    redirect_to "#{origin}#{request.path}", allow_other_host: true, status: :found
  end
end
