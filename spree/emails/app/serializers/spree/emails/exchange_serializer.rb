module Spree
  module Emails
    class ExchangeSerializer < Spree::Api::V3::ExchangeSerializer
      _attributes.delete(:custom_fields)

      without_display_money

      # What is going back, at the quantities the customer named.
      many :items,
           source: proc { exchange_line_items },
           resource: Spree::Emails::ParcelItemSerializer

      # What comes out in their place, one line per replacement.
      many :replacements,
           source: proc { exchange_line_items },
           resource: Spree::Emails::ReplacementItemSerializer

      one :stock_location, resource: Spree::Emails::StockLocationSerializer
      typelize reason_name: [:string, nullable: true], memo: [:string, nullable: true]

      # The note on the request — the customer's own when it is acknowledged.
      attributes :memo

      attribute :reason_name do |exchange|
        exchange.reason&.name
      end
    end
  end
end
