require 'spec_helper'

RSpec.describe Spree::Api::V3::OrderSerializer do
  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store) }
  let(:params) { { store: store, locale: 'en', currency: store.default_currency, user: nil, includes: [], expand: [] } }

  before { Spree.hooks.register('returns.create.validate', 'Spree::Returns::EligibilityValidator') }

  describe 'returns_eligibility' do
    subject(:eligibility) { described_class.new(order, params: params).to_h['returns_eligibility'].deep_stringify_keys }

    it 'says the order is open to returns, with the window it closes on' do
      expect(eligibility).to include(
        'eligible' => true,
        'errors' => [],
        'return_window_ends_at' => (order.completed_at + 30.days).iso8601
      )
    end

    it 'gives the reason the create call would give once the window has closed' do
      order.update_columns(completed_at: 60.days.ago)

      expect(eligibility['eligible']).to be(false)
      expect(eligibility['errors'].first).to include('code' => 'outside_return_window')
    end
  end
end
