module Spree
  module Emails
    # One returned line as it was credited. A customer who bought three and
    # sent one must see one, so the quantity and amount are this return's share
    # rather than the whole line's.
    class ReturnedItemSerializer < Spree::Emails::BaseSerializer
      include Spree::Emails::PurchasedItemAttributes

      attribute :id do |item|
        item.line_item.prefixed_id
      end

      attribute :name do |item|
        item.line_item.name
      end

      attribute :slug do |item|
        item.line_item.slug
      end

      attribute :quantity, &:credited_quantity

      attribute :sku do |item|
        item.line_item.sku
      end

      attribute :options_text do |item|
        item.line_item.options_text
      end

      many :option_values,
           source: proc { line_item.option_values },
           resource: Spree::Emails::OptionValueSerializer

      attribute :price do |item|
        Spree::Money::Rounding.format(item.line_item.price, item.line_item.currency, unit_price: true)
      end

      # List price for the credited units, same as a parcel's share. What was
      # actually paid back is `return.refunded_total` on the parent.
      attribute :amount do |item|
        Spree::Money::Rounding.format(item.line_item.price * item.credited_quantity, item.line_item.currency)
      end
    end
  end
end
