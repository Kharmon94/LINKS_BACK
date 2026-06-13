# frozen_string_literal: true

module Api
  module V1
    class CustomDomainsController < BaseController
      before_action :require_custom_domains!
      before_action :set_domain, only: %i[update destroy verify]

      def index
        render json: { domains: billing_account.custom_domains.order(created_at: :desc).map(&:as_json_for_client) }
      end

      def create
        if billing_account.at_custom_domain_limit?
          return render json: {
            error: "You've reached your tier limit for custom domains. Upgrade to add more.",
            upgrade_url: "/pricing"
          }, status: :forbidden
        end

        domain = billing_account.custom_domains.build(domain_params)
        authorize! :create, domain

        if domain.save
          render json: { domain: domain.as_json_for_client }, status: :created
        else
          render json: { error: domain.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def update
        authorize! :update, @domain
        if params[:is_default].present? && ActiveModel::Type::Boolean.new.cast(params[:is_default])
          unless @domain.verified?
            return render json: { error: "Domain must be verified before setting as default" },
                          status: :unprocessable_entity
          end
          @domain.set_as_default!
        end
        render json: { domain: @domain.reload.as_json_for_client }
      end

      def destroy
        authorize! :destroy, @domain
        if @domain.is_default?
          return render json: { error: "Cannot remove the default domain. Set another domain as default first." },
                        status: :unprocessable_entity
        end

        @domain.destroy!
        head :no_content
      end

      def verify
        authorize! :update, @domain
        if verify_domain_dns?(@domain)
          @domain.verify!
          render json: { domain: @domain.as_json_for_client }
        else
          render json: { error: "DNS verification failed. Ensure the TXT record is configured correctly." },
                 status: :unprocessable_entity
        end
      end

      private

      def billing_account
        current_user.billing_account
      end

      def require_custom_domains!
        unless CustomDomain.allowed_for?(current_user)
          return render json: { error: "Custom domains are not available on your plan" }, status: :forbidden
        end

        unless Permissions::Rules::CAMPAIGN_MANAGER_ROLES.include?(current_user.team_role)
          return render json: { error: "Only team owners and admins can manage custom domains" }, status: :forbidden
        end
      end

      def set_domain
        @domain = billing_account.custom_domains.find(params[:id])
      end

      def domain_params
        params.require(:domain).permit(:domain)
      rescue ActionController::ParameterMissing
        params.permit(:domain)
      end

      def verify_domain_dns?(domain)
        return true if Rails.env.test? && params[:force].present?

        Resolv::DNS.open do |dns|
          txt_name = "_links-verification.#{domain.domain}"
          records = dns.getresources(txt_name, Resolv::DNS::Resource::IN::TXT)
          records.any? { |record| record.strings.join.include?(domain.verification_token) }
        end
      rescue Resolv::ResolvError
        false
      end
    end
  end
end
