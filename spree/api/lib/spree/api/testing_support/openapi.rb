require 'spree/api/testing_support/agent_tools'

module Spree
  module Api
    module TestingSupport
      # Documents a write endpoint's request body from the controller's
      # `request_params` declaration, so no integration spec describes a body by hand.
      #
      #   path '/api/v3/admin/products' do
      #     post 'Create a product' do
      #       request_body_for
      #
      # The body references the `<Resource>CreateParams` / `<Resource>UpdateParams`
      # component, registered with every shared shape it uses under the spec's
      # `components.schemas`. The SDK request types are generated from those
      # components.
      module RequestBody
        # @param action [Symbol, nil] the controller action; read from the route
        #   when omitted
        # @param controller [Class, nil] resolved from the path when omitted
        # @param required [Boolean] false for an endpoint that accepts no body
        def request_body_for(action = nil, controller: nil, required: true)
          route = request_body_route
          action ||= route[:action].to_sym
          controller ||= "#{route[:controller]}_controller".camelize.constantize
          schema = controller.request_params_schema(action)
          raise "#{controller.name} does not declare request_params for #{action}" unless schema

          name = schema.component_name(action)
          register_request_schema(name, schema.json_schema(action.in?(%i[create update]) ? action : nil))
          schema.shapes.each { |shape| register_request_schema(shape.name, shape.json_schema) }
          schema.code_lists.each { |list_name, definition| register_request_schema(list_name, definition) }

          parameter name: :body, in: :body, required: required, schema: { '$ref': "#/components/schemas/#{name}" }
        end

        # Documents a shape a read endpoint takes as query parameters, and publishes
        # it as a component so the SDKs generate one type for it.
        #
        # @param shape [Spree::Api::V3::RequestSchema] a named shape
        def query_parameters_for(shape)
          register_request_schema(shape.name, shape.json_schema)
          shape.code_lists.each { |list_name, definition| register_request_schema(list_name, definition) }

          shape.json_schema[:properties].each do |name, property|
            parameter name: name, in: :query, required: false, description: property[:description],
                      schema: property.except(:description)
          end
        end

        private

        def request_body_route
          path = metadata[:path_item][:template].gsub(/\{[^}]+\}/, 'x1')
          Rails.application.routes.recognize_path(path, method: metadata[:operation][:verb])
        end

        def register_request_schema(name, definition)
          spec = RSpec.configuration.openapi_specs.fetch(metadata[:openapi_spec] || metadata[:swagger_doc])
          schemas = (spec[:components] ||= {})[:schemas] ||= {}
          definition = definition.deep_stringify_keys

          if schemas.key?(name) && schemas[name].deep_stringify_keys != definition
            raise "Two request schemas are named #{name}; " \
                  'name one of the request_params declarations or shapes differently'
          end

          schemas[name] = definition
          # Request schemas follow the response ones, sorted, so the written spec
          # does not depend on the order specs ran in.
          request, response = schemas.partition { |key, _| key.to_s.end_with?('Params') }
          spec[:components][:schemas] = response.to_h.merge(request.sort_by { |key, _| key.to_s }.to_h)
        end
      end

      # Appends a `**Required scope:**` line to the operation description, to
      # surface scope requirements in the rendered docs without inventing a
      # custom OpenAPI extension.
      #
      #   admin_scope :read, :orders
      #   admin_scope :write, :customers
      module AdminScope
        def admin_scope(action, resource)
          admin_scope_note("`#{action}_#{resource}`")
        end

        # Free-form variant for endpoints whose required scope is resolved at
        # request time (e.g. exports — gated by the exported resource's scope).
        def admin_scope_note(text)
          line = "**Required scope:** #{text} (for API-key authentication)."
          existing = metadata[:operation][:description].to_s
          metadata[:operation][:description] = existing.empty? ? line : "#{existing}\n\n#{line}"
        end
      end

      # What an extension needs to generate the `openapi/admin.yaml` its gem
      # ships, which Spree merges into the document agents, API docs and SDKs
      # read (Spree::Api::AdminDocument). In the extension's swagger helper:
      #
      #   require 'rswag/specs'
      #   require 'spree/api/testing_support/openapi'
      #
      #   RSpec.configure do |config|
      #     Spree::Api::TestingSupport::Openapi.configure(
      #       config, engine: MyExtension::Engine, title: 'My Extension Admin API'
      #     )
      #   end
      #
      # and in its Rakefile, `require 'spree/api/testing_support/openapi_tasks'`
      # for `rake spree:openapi:generate`.
      #
      # See docs/plans/6.0-agent-tools-from-openapi.md.
      module Openapi
        HELPERS = [RequestBody, AdminScope, AgentTools].freeze

        class << self
          # @param config [RSpec::Core::Configuration]
          # @param engine [Class<Rails::Engine>]
          # @param title [String]
          # @param description [String, nil]
          # @return [void]
          def configure(config, engine:, title:, description: nil)
            config.openapi_root = engine.root.to_s
            config.openapi_specs = { Spree::Api::AdminDocument::EXTENSION_PATH => admin_document(title, description) }
            config.openapi_format = :yaml
            HELPERS.each { |helper| config.extend helper, type: :request }
          end

          # The skeleton of an extension's admin document: the same security
          # schemes as core's, so its operations authenticate the same way.
          #
          # @return [Hash]
          def admin_document(title, description = nil)
            {
              openapi: '3.0.3',
              info: { title: title, version: 'v3', description: description }.compact,
              paths: {},
              components: {
                securitySchemes: {
                  api_key: { type: :apiKey, name: 'x-spree-api-key', in: :header,
                             description: 'Secret API key for admin access' },
                  bearer_auth: { type: :http, scheme: :bearer, bearerFormat: 'JWT',
                                 description: 'JWT token for admin user authentication' }
                }
              }
            }
          end
        end
      end
    end
  end
end
