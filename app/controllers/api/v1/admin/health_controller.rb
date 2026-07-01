# frozen_string_literal: true

require "socket"
require "uri"

module Api
  module V1
    module Admin
      class HealthController < BaseController
        def show
          authorize! :read, :admin_health
          render json: { health: health_payload }
        end

        private

        def health_payload
          {
            database: database_status,
            redis: redis_status,
            stripe: { configured: StripeMode.secret_key.present? },
            mail: mail_status,
            version: app_version,
            migrationVersion: ActiveRecord::Migrator.current_version
          }
        end

        def mail_status
          {
            resendConfigured: ENV["RESEND_API_KEY"].present?,
            mailerFrom: ApplicationMailer.default[:from],
            queueAdapter: Rails.application.config.active_job.queue_adapter.to_s
          }
        end

        def database_status
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          ActiveRecord::Base.connection.execute("SELECT 1")
          latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
          { ok: true, latencyMs: latency_ms }
        rescue StandardError
          { ok: false, latencyMs: nil }
        end

        def redis_status
          url = ENV["REDIS_URL"]
          return { ok: true, skipped: true } if url.blank?

          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          uri = URI.parse(url)
          socket = TCPSocket.new(uri.host, uri.port || 6379)
          socket.write("*1\r\n$4\r\nPING\r\n")
          response = socket.readpartial(256)
          socket.close
          ok = response.include?("PONG")
          latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
          { ok: ok, skipped: false, latencyMs: latency_ms }
        rescue StandardError
          { ok: false, skipped: false }
        end

        def app_version
          ENV["RAILWAY_GIT_COMMIT_SHA"].presence || git_sha_from_repo
        end

        def git_sha_from_repo
          head_path = Rails.root.join(".git/HEAD")
          return nil unless head_path.exist?

          head = head_path.read.strip
          sha = if head.start_with?("ref:")
                  ref = head.split(" ", 2).last
                  ref_path = Rails.root.join(".git", ref)
                  ref_path.exist? ? ref_path.read.strip : nil
                else
                  head
                end
          sha&.slice(0, 7)
        rescue StandardError
          nil
        end
      end
    end
  end
end
