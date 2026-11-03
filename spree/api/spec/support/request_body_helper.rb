# Moved into the gem, where an extension can document its own endpoints with
# it; see Spree::Api::TestingSupport::RequestBody.
require 'spree/api/testing_support/openapi'

RequestBodyHelper = Spree::Api::TestingSupport::RequestBody

RSpec.configure do |config|
  config.extend RequestBodyHelper, type: :request
end
