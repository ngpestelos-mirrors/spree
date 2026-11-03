module Spree
  module Returns
    # Customers send back only what reached them and was sold as returnable.
    #
    # A unit must belong to a fulfillment that has shipped, and its line item
    # must carry `returnable`, which is frozen from the variant when the order
    # is placed — so a product marked final sale after the sale does not take
    # back a right already granted (docs/plans/6.1-returns-portal.md). This is
    # where a store states the EU exemptions for sealed, personalised or
    # perishable goods (Consumer Rights Directive Art. 16).
    #
    # Advisory for staff, like the return window: a merchant may still take
    # back a final-sale item for a good customer.
    class ReturnableValidator
      # @param workflow [Spree::Returns::Create, Spree::Exchanges::Create]
      def call(workflow)
        return if workflow.created_by.present?

        units = Array(workflow.items).filter_map { |item| item[:fulfillment_item] }

        unshipped = units.reject { |unit| shipped?(unit) }
        reject(workflow, :not_shipped, unshipped) if unshipped.any?

        final_sale = units.reject { |unit| unit.line_item&.returnable? }
        reject(workflow, :not_returnable, final_sale) if final_sale.any?
      end

      private

      def shipped?(unit)
        unit.fulfillment.present? && (unit.fulfillment.fulfilled? || unit.fulfillment.delivered?)
      end

      def reject(workflow, code, units)
        workflow.errors.add(
          :base,
          code,
          message: I18n.t("spree.return_errors.#{code}", items: units.map { |unit| unit.variant.name }.uniq.to_sentence)
        )
        workflow.reject!
      end
    end
  end
end
