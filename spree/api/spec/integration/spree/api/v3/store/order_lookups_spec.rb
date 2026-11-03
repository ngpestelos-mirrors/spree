# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Order Lookups API', type: :request, swagger_doc: 'api-reference/store.yaml', events: true do
  include_context 'API v3 Store'

  let!(:order) { create(:shipped_order, store: store).tap { |order| order.update_columns(email: 'guest@example.com') } }

  path '/api/v3/store/order_lookups' do
    post 'Find an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC.squish
        "Find my order" for a guest who lost the confirmation email. When the order number and email match an order,
        a link to it is emailed to that address. The answer is always 202, match or not, so it never reveals which
        address placed an order.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      request_body_for

      let(:'x-spree-api-key') { api_key.token }

      response '202', 'lookup accepted' do
        let(:body) { { number: order.number.downcase, email: 'Guest@Example.com' } }

        schema type: :object, properties: { message: { type: :string } }, required: %w[message]

        before { allow(Spree::Events).to receive(:publish).and_call_original }

        run_test! do
          expect(Spree::Events).to have_received(:publish).with('order.lookup_requested', hash_including('email' => 'guest@example.com'), anything)
        end
      end

      response '202', 'lookup accepted for a miss, without saying so' do
        let(:body) { { number: order.number, email: 'someone-else@example.com' } }

        schema type: :object, properties: { message: { type: :string } }, required: %w[message]

        before { allow(Spree::Events).to receive(:publish).and_call_original }

        run_test! do
          expect(Spree::Events).not_to have_received(:publish).with('order.lookup_requested', anything, anything)
        end
      end
    end
  end
end
