# frozen_string_literal: true

# Allow GET to start OAuth (SPA uses window.location to API host).
# Mitigate CSRF: only trusted SPA should link to this URL; prefer POST + CSRF when serving HTML from Rails.
OmniAuth.config.allowed_request_methods = %i[get post]
OmniAuth.config.silence_get_warning = true
