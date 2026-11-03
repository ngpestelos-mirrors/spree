module Spree
  module Returns
    # What a customer would be told if they asked to send something back from
    # this order now, before they have picked anything.
    #
    # The verdict comes from the `returns.create.validate` handlers
    # themselves, run with nothing written (Spree::Workflow.check_hook), so a
    # storefront shows exactly what the create call would answer — including
    # the rules a store registered on its own. Nothing here restates a rule.
    #
    # Read through Spree::Order#returns_eligibility, which memoizes it per
    # order instance so one serialization pays for it once.
    class Eligibility
      # The workflow's own refusals, which run before its hooks.
      ORDER_ERRORS = {
        order_canceled: :canceled?,
        order_not_completed: :incomplete?
      }.freeze

      attr_reader :order

      # @param order [Spree::Order]
      def initialize(order)
        @order = order
      end

      # @return [Boolean] whether the order is open to customer returns at all
      def eligible?
        errors.empty?
      end

      # Why the order is closed to customer returns, as code and message pairs
      # a storefront can show or translate.
      #
      # @return [Array<Hash{Symbol => String}>]
      def errors
        @errors ||= order_errors.presence || hook_errors(items: [])
      end

      # How much of one shipped unit the customer may still send back, and
      # why not when the answer is nothing.
      #
      # @param unit [Spree::FulfillmentItem]
      # @return [Hash] `{ returnable_quantity: Integer, non_returnable_reason: String | nil }`
      def for_unit(unit)
        remaining = unit.quantity.to_i - claimed_quantities.fetch(unit.id, 0)
        reason =
          if remaining <= 0
            'already_returned'
          elsif !eligible?
            errors.first[:code]
          else
            hook_errors(items: [{ fulfillment_item: unit, quantity: remaining }]).first&.dig(:code)
          end

        { returnable_quantity: reason ? 0 : remaining, non_returnable_reason: reason }
      end

      # @return [Hash] the shape the Store API serves
      def to_h
        {
          eligible: eligible?,
          errors: errors,
          return_window_ends_at: order.return_window_ends_at&.iso8601,
          withdrawal_period_ends_at: order.withdrawal_period_ends_at&.iso8601
        }
      end

      private

      def order_errors
        ORDER_ERRORS.filter_map do |code, check|
          next unless send(check)

          { code: code.to_s, message: I18n.t("spree.return_errors.#{code}") }
        end.first(1)
      end

      def canceled?
        order.canceled?
      end

      def incomplete?
        !order.completed?
      end

      def hook_errors(items:)
        errors = Spree.return_create_workflow.check_hook(
          :validate,
          order: order, items: items, stock_location: nil, reason: nil, memo: nil, created_by: nil
        )

        errors.map do |error|
          { code: error.type.is_a?(Symbol) ? error.type.to_s : 'rejected', message: error.message }
        end
      end

      def claimed_quantities
        @claimed_quantities ||= Spree::Returns::ReturnableQuantity.claimed_quantities(order.fulfillment_items.map(&:id))
      end
    end
  end
end
