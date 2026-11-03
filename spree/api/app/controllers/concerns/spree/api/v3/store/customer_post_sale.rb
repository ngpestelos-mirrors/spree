module Spree
  module Api
    module V3
      module Store
        # The customer's side of returns, exchanges and claims. Every record
        # hangs off an order the customer owns — by JWT or by guest token,
        # mirroring Store::OrdersController — and that ownership is the whole
        # authorization: the scope is that order's own records.
        #
        # Opening a record and withdrawing it before the merchant acts are the
        # customer's; approving, receiving and refunding stay with the
        # merchant, through the Admin API.
        module CustomerPostSale
          extend ActiveSupport::Concern

          # PATCH .../:id/cancel
          #
          # Only while the request is still `requested`. Once the merchant has
          # approved it, and possibly bought a label, withdrawing is theirs.
          def cancel
            unless @resource.requested?
              @resource.errors.add(:base, :not_cancelable, message: I18n.t('spree.return_errors.not_cancelable'))
              return render_validation_error(@resource.errors)
            end

            render_result(cancel_workflow.call(workflow_record_key => @resource))
          end

          protected

          def set_parent
            cart_pk = Spree::Cart.decode_own_prefixed_id(params[:order_id])
            @parent = if cart_pk
                        order_scope.find_by!(cart_id: cart_pk)
                      else
                        order_scope.find_by_prefix_id!(params[:order_id])
                      end
          end

          # Authorization is the parent order's: set_parent already proved this
          # customer owns it, and the scope is that order's own records.
          def set_resource
            @resource = find_resource
          end

          def order_scope
            storefront_access_policy.scope(current_store.orders.complete, token: order_token)
          end

          def create_params
            @create_params ||= params.permit(*declared_permitted_attributes)
          end

          # The units coming back, resolved through the customer's own order.
          #
          # @return [Spree::FulfillmentItem]
          def fulfillment_item_for(id)
            @parent.fulfillment_items.find_by_prefix_id!(id)
          end

          # Read through the store so a reason belonging to another store 404s
          # rather than being silently attached.
          def return_reason_for_create
            return nil if create_params[:reason_id].blank?

            current_store.return_reasons.find_by_prefix_id!(create_params[:reason_id])
          end

          def cancel_workflow
            raise NotImplementedError, "#{self.class} must implement #cancel_workflow"
          end

          def workflow_record_key
            raise NotImplementedError, "#{self.class} must implement #workflow_record_key"
          end
        end
      end
    end
  end
end
