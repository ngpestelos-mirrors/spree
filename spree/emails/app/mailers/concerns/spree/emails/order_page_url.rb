module Spree
  module Emails
    # Where a returns email sends the customer: their account's order page
    # when the order belongs to an account, or the guest order page with the
    # order token, which is how a guest opens an order without signing in.
    #
    # Built in the mailer and never serialized: the token opens the order.
    module OrderPageUrl
      private

      def order_page_url(order)
        base = current_store.storefront_url
        return URI.join(base, "/account/orders/#{order.prefixed_id}").to_s if order.customer_id.present?

        append_token(URI.join(base, "/orders/#{order.prefixed_id}").to_s, order.token)
      end

      def return_policy_url
        URI.join(current_store.storefront_url, '/policies/return-policy').to_s
      end
    end
  end
end
