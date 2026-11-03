# frozen_string_literal: true

module Spree
  class ExchangeEmailSubscriber < Spree::Subscriber
    subscribes_to 'exchange.requested', 'exchange.approved'

    on 'exchange.requested', :send_requested_email
    on 'exchange.approved', :send_approved_email

    private

    def send_requested_email(event)
      deliver(event) { |exchange| ExchangeMailer.requested_email(exchange.id) }
    end

    def send_approved_email(event)
      deliver(event) { |exchange| ExchangeMailer.approved_email(exchange.id) }
    end

    def deliver(event)
      exchange = Spree::Exchange.find_by_prefix_id(event.payload['id'])
      return unless exchange
      return unless exchange.store.prefers_send_consumer_transactional_emails?

      yield(exchange).deliver_later
    end
  end
end
