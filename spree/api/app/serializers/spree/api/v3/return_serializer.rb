# frozen_string_literal: true

module Spree
  module Api
    module V3
      # Customer-facing view of a return. No timestamps, no internal notes,
      # no staff attribution — see the serializer rules in CLAUDE.md.
      class ReturnSerializer < BaseSerializer
        typelize number: :string,
                 status: [:string, enum: Spree::Return.statuses, enum_type_name: 'ReturnStatus'],
                 order_id: [:string, nullable: true],
                 reason_id: [:string, nullable: true],
                 approved_at: [:string, nullable: true],
                 received_at: [:string, nullable: true],
                 refunded_at: [:string, nullable: true],
                 canceled_at: [:string, nullable: true],
                 memo: [:string, nullable: true],
                 cancelable: :boolean, label_available: :boolean,
                 tracking: [:string, nullable: true], tracking_url: [:string, nullable: true]

        # The memo is the customer's own note on the request.
        attributes :number, :status, :memo

        # Whether the customer may still withdraw the request: only before the
        # merchant has acted on it.
        attribute :cancelable, &:requested?

        # Whether a prepaid label is waiting to be downloaded from the label
        # endpoint. The label row stays off the wire — its cost and provider
        # ids are merchant data.
        attribute :label_available do |return_record|
          return_record.active_shipping_label.present?
        end

        # Where the parcel coming back is, as the carrier last reported it.
        attribute :tracking do |return_record|
          return_record.deliveries.last&.tracking_number
        end

        attribute :tracking_url do |return_record|
          return_record.deliveries.last&.resolved_tracking_url
        end

        prefixed_id_attributes :order, :reason

        money_attributes :refund_total, :display_refund_total
        # The tax inside refund_total.
        money_attributes :refund_tax_total, :display_refund_tax_total

        attribute :approved_at do |return_record|
          return_record.approved_at&.iso8601
        end

        attribute :received_at do |return_record|
          return_record.received_at&.iso8601
        end

        attribute :refunded_at do |return_record|
          return_record.refunded_at&.iso8601
        end

        attribute :canceled_at do |return_record|
          return_record.canceled_at&.iso8601
        end

        one :reason, resource: proc { Spree.api.return_reason_serializer }, if: proc { expand?('reason') }

        many :return_line_items,
             resource: proc { Spree.api.return_line_item_serializer },
             if: proc { expand?('return_line_items') }

        expandable_custom_fields
      end
    end
  end
end
