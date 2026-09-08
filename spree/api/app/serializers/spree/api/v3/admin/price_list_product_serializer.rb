module Spree
  module Api
    module V3
      module Admin
        # A product as the price list's own page reads it: what the card
        # renders, plus what the list charges for it per variant — a ladder
        # shown where it is edited and not only where it is sold
        # (docs/plans/6.0-volume-pricing.md).
        #
        # Deliberately not a subclass of the admin product serializer. This
        # endpoint feeds one membership card and the picker's exclusion list,
        # neither of which reads a product's status, media, categories,
        # publications, channels or custom fields — and the page already
        # renders a variant row per product, so a full product payload per row
        # is the difference between a card that opens and one that crawls.
        # A field the card starts needing is one line here.
        #
        # `price_list_price` is expanded rather than always sent, because
        # resolving it costs a query per page that the picker has no use for.
        class PriceListProductSerializer < V3::BaseSerializer
          typelize name: :string, thumbnail_url: [:string, nullable: true],
                   price_list_price: ['CatalogPrice', nullable: true]

          attributes :name

          # The card's row image.
          attribute :thumbnail_url do |product|
            image_url_for(product.primary_media)
          end

          # Priced off the same variant the row's own price is read from.
          # Null means nothing prices this variant in this currency at all.
          attribute :price_list_price, if: proc { expand?('price_list_price') } do |product|
            resolver = params[:price_list_price_resolver]
            price = resolver&.call(featured_variant(product))

            Spree.api.admin_catalog_price_serializer.new(price, params: params).to_h if price
          end

          # Every variant with what this list charges for it, each with its
          # own ladder. `source:` rather than an association: the rows are
          # resolved per request against the list, which the serializer
          # receives in params.
          many :price_list_variants,
               resource: proc { Spree.api.admin_catalog_price_serializer },
               if: proc { expand?('price_list_price') },
               source: lambda { |params|
                 resolver = params[:price_list_price_resolver]

                 variants.filter_map { |variant| resolver&.call(variant) }
               }
        end
      end
    end
  end
end
