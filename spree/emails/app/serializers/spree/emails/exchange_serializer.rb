module Spree
  module Emails
    class ExchangeSerializer < Spree::Api::V3::ExchangeSerializer
      _attributes.delete(:custom_fields)

      without_display_money

      # What is going back, at the quantities the customer named.
      many :items,
           source: proc { exchange_line_items },
           resource: Spree::Emails::ParcelItemSerializer

      typelize replacements: 'Array<{ name: string | null; options_text: string | null; quantity: number }>'

      # What comes out in their place, one line per replacement.
      attribute :replacements do |exchange|
        exchange.exchange_line_items.map do |line|
          { name: line.new_variant&.name, options_text: line.new_variant&.options_text, quantity: line.quantity }
        end
      end

      one :stock_location, resource: Spree::Emails::StockLocationSerializer
      typelize reason_name: [:string, nullable: true]

      attribute :reason_name do |exchange|
        exchange.reason&.name
      end
    end
  end
end
