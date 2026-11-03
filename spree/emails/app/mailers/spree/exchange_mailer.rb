module Spree
  class ExchangeMailer < BaseMailer
    include Spree::Emails::OrderPageUrl

    # Acknowledges an exchange request the moment it is opened — the same
    # durable confirmation a return gets (Consumer Rights Directive Art. 11(3)).
    def requested_email(exchange)
      deliver_exchange_email(exchange)
    end

    # Tells the customer where to send the goods going back.
    def approved_email(exchange)
      deliver_exchange_email(exchange)
    end

    private

    def deliver_exchange_email(exchange)
      @exchange = exchange.respond_to?(:id) ? exchange : Spree::Exchange.find(exchange)
      @order = @exchange.order
      @current_store = @exchange.store || Spree::Store.default

      with_store_locale(current_store, @order.locale) do
        mail_template(
          {
            exchange: email_data(@exchange, Spree::Emails::ExchangeSerializer),
            order: email_data(@order, Spree::Emails::OrderSerializer),
            order_url: order_page_url(@order),
            policy_url: return_policy_url
          },
          to: @order.email, store_url: current_store.storefront_url
        )
      end
    end
  end
end
