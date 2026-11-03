module Spree
  module Api
    module V3
      module Store
        # "Find my order" for a guest who lost the confirmation email.
        #
        # The server checks the order number and email together, and on a
        # match sends a link to the order to the order's own address — the
        # inbox is the proof of identity. The answer is the same 202 either
        # way: order numbers are sequential and printed on parcels, so telling
        # a match from a miss would let anyone holding a number find out which
        # address placed it (docs/plans/6.1-returns-portal.md).
        class OrderLookupsController < Store::BaseController
          allow_guest_storefront_access!
          rate_limit to: Spree::Api::Config[:rate_limit_password_reset],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     with: RATE_LIMIT_RESPONSE

          skip_before_action :authenticate_user

          request_params 'CreateOrderLookupParams', action: :create do |body|
            body.attribute :number, :string, required: true, example: 'R123456789', description: 'The order number.'
            body.attribute :email, :string, required: true, format: :email, example: 'customer@example.com',
              description: 'The email the order was placed with.'
          end

          # POST /api/v3/store/order_lookups
          def create
            order = matching_order
            order&.publish_event('order.lookup_requested', order.event_payload_for('order.lookup_requested', store: current_store))

            render json: { message: I18n.t('spree.api.order_lookup_requested') }, status: :accepted
          end

          private

          def matching_order
            number = params[:number].to_s.strip
            email = params[:email].to_s.strip
            return nil if number.blank? || email.blank?

            order = current_store.orders.complete.find_by(number: number.upcase)
            order if order&.email.to_s.casecmp?(email)
          end
        end
      end
    end
  end
end
