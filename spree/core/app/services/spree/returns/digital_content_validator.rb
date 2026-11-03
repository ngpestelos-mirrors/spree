module Spree
  module Returns
    # Digital content cannot come back once it has been handed over: there is
    # nothing to send, and the EU right of withdrawal ends when supply begins
    # (Consumer Rights Directive Art. 16(m)). Advisory for staff, who may
    # still refund a download that never worked.
    class DigitalContentValidator
      # @param workflow [Spree::Returns::Create, Spree::Exchanges::Create]
      def call(workflow)
        return if workflow.created_by.present?

        digital = Array(workflow.items).filter_map { |item| item[:fulfillment_item] }.select do |unit|
          unit.fulfillment&.digital?
        end
        return if digital.empty?

        workflow.errors.add(
          :base,
          :digital_content,
          message: I18n.t('spree.return_errors.digital_content', items: digital.map { |unit| unit.variant.name }.uniq.to_sentence)
        )
        workflow.reject!
      end
    end
  end
end
