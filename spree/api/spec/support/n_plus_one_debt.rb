# Spec files whose requests still repeat a query. Their examples log the
# report instead of failing; every other file, and every new one, fails on
# the first repeated statement. Fix the cause and delete the line — the list
# only shrinks, and new work never adds to it.
#
# Before treating an entry as debt, confirm the query count actually grows
# with the number of records. Two associations on one table (an order's
# billing and shipping address) share a fingerprint and report as a repeat
# while costing one query each however many records are rendered; those are
# preloaded, not rewritten.
N_PLUS_ONE_DEBT = %w[
  spec/controllers/spree/api/v3/admin/catalogs/quantity_rules_controller_spec.rb
  spec/controllers/spree/api/v3/admin/companies_controller_spec.rb
  spec/controllers/spree/api/v3/admin/customer_groups_controller_spec.rb
  spec/controllers/spree/api/v3/admin/customers_controller_spec.rb
  spec/controllers/spree/api/v3/admin/customers_gdpr_spec.rb
  spec/controllers/spree/api/v3/admin/dashboard_controller_spec.rb
  spec/controllers/spree/api/v3/admin/delivery_methods_controller_spec.rb
  spec/controllers/spree/api/v3/admin/delivery_profiles_controller_spec.rb
  spec/controllers/spree/api/v3/admin/external_references_spec.rb
  spec/controllers/spree/api/v3/admin/imports_controller_spec.rb
  spec/controllers/spree/api/v3/admin/media_library_controller_spec.rb
  spec/controllers/spree/api/v3/admin/order_groups_controller_spec.rb
  spec/controllers/spree/api/v3/admin/orders/fulfillments_controller_spec.rb
  spec/controllers/spree/api/v3/admin/orders_controller_spec.rb
  spec/controllers/spree/api/v3/admin/price_lists_controller_spec.rb
  spec/controllers/spree/api/v3/admin/products/media_controller_spec.rb
  spec/controllers/spree/api/v3/admin/products/variants_controller_spec.rb
  spec/controllers/spree/api/v3/admin/products_controller_spec.rb
  spec/controllers/spree/api/v3/admin/reporting_controller_spec.rb
  spec/controllers/spree/api/v3/admin/returns_controller_spec.rb
  spec/controllers/spree/api/v3/admin/sellers/payouts_controller_spec.rb
  spec/controllers/spree/api/v3/admin/sellers_controller_spec.rb
  spec/controllers/spree/api/v3/admin/stock_levels_controller_spec.rb
  spec/controllers/spree/api/v3/seller/balances_controller_spec.rb
  spec/controllers/spree/api/v3/seller/imports_controller_spec.rb
  spec/controllers/spree/api/v3/seller/orders/fulfillments_controller_spec.rb
  spec/controllers/spree/api/v3/store/carts_controller_spec.rb
  spec/controllers/spree/api/v3/store/carts_split_checkout_spec.rb
  spec/controllers/spree/api/v3/store/companies/orders_controller_spec.rb
  spec/controllers/spree/api/v3/store/delivery_methods_controller_spec.rb
  spec/integration/spree/api/v3/admin/customer_groups_spec.rb
  spec/integration/spree/api/v3/admin/imports_spec.rb
  spec/integration/spree/api/v3/admin/orders/fulfillments_spec.rb
  spec/integration/spree/api/v3/admin/price_lists_spec.rb
  spec/integration/spree/api/v3/admin/stock_transfers_spec.rb
  spec/integration/spree/api/v3/store/carts_spec.rb
  spec/integration/spree/api/v3/store/line_items_spec.rb
  spec/requests/spree/api/v3/seller/import_flow_spec.rb
].freeze

RSpec.configure do |config|
  config.around(:each) do |example|
    # rerun_file_path names the spec file even for rswag examples, which
    # are defined inside the gem.
    if defined?(Prosopite) && N_PLUS_ONE_DEBT.include?(example.metadata[:rerun_file_path].delete_prefix('./'))
      Prosopite.raise = false
      begin
        example.run
      ensure
        Prosopite.raise = true
      end
    else
      example.run
    end
  end
end
