module Spree
  module Api
    # Fills {Spree::AgentTools::OperationCatalog} from the merged Admin API
    # document ({AdminDocument}) and the routes behind it.
    #
    # Every write operation that is not a resource's plain create, update or
    # destroy becomes a tool — cancel, capture, approve, send — unless its
    # spec opts it out with a reason. CRUD stays with the generic tools, and a
    # read becomes a tool only when its spec opts it in. Nothing here is a
    # list of tools: an endpoint that gains an rswag spec is a tool in the
    # same commit, core's or an extension's.
    #
    # See docs/plans/6.0-agent-tools-from-openapi.md.
    module AgentOperations
      WRITE_VERBS = %w[post patch put delete].freeze
      CRUD_ACTIONS = %w[index show create update destroy].freeze
      ADMIN_PREFIX = '/api/v3/admin/'.freeze

      # The opt-out and opt-in marks an rswag spec sets (see the `agent_tool`
      # spec helper), and the reason an opt-out must carry.
      AGENT_KEY = 'x-spree-agent'.freeze
      REASON_KEY = 'x-spree-agent-reason'.freeze

      # The line `admin_scope` appends to a description. It is for the
      # rendered docs; a tool is already offered only to a key holding it.
      SCOPE_NOTE = /^\*\*Required scope:\*\*.*$/

      class << self
        # Registers this walk as how the catalog fills itself, and marks it
        # stale so the next reader gets a fresh one.
        #
        # @return [void]
        def stale!
          Spree::AgentTools::OperationCatalog.deriver = -> { install }
          Spree::AgentTools::OperationCatalog.stale!
          Spree::AgentTools::OperationTool.clear_cache!
          AdminDocument.reset!
          AgentWriteSchemas.reset!
        end

        # @param catalog [Module] defaults to the core catalog
        # @return [Integer] how many operations were registered
        def install(catalog: Spree::AgentTools::OperationCatalog)
          catalog.reset!

          entries = candidates.filter_map { |candidate| entry_for(candidate) }
          aliases = legacy_entries(entries)
          entries.each { |entry| entry.delete(:legacy_names) }
          listed = resolve_collisions(entries.select { |entry| entry[:listed] })
          (listed + aliases).each { |entry| catalog.register(**entry) }

          listed.size
        end

        # Every admin operation in the document, with the route and
        # controller it resolves to. Public for the contract spec, which
        # reports the operations that resolve to nothing.
        #
        # @return [Array<Hash>]
        def candidates
          routes = route_index

          Array(AdminDocument.document['paths']).flat_map do |path, operations|
            next [] unless path.start_with?(ADMIN_PREFIX)

            operations.filter_map do |verb, operation|
              next unless operation.is_a?(Hash) && (WRITE_VERBS + ['get']).include?(verb)

              { path: path, verb: verb, operation: operation, route: routes[[verb, path]] }
            end
          end
        end

        # Whether an operation becomes a listed tool, and if not, why.
        #
        # @param candidate [Hash]
        # @return [Symbol] :included, :crud, :read, :opted_out, :unrouted,
        #   :unscoped or :withheld
        def disposition(candidate)
          return :unrouted if candidate[:route].nil?

          controller = candidate[:route][:controller]
          return :unscoped if controller.nil? || scope_of(controller).blank?
          return :withheld if withheld?(controller)

          flag = candidate[:operation][AGENT_KEY]
          return :opted_out if flag == false

          if candidate[:verb] == 'get'
            flag == true ? :included : :read
          elsif CRUD_ACTIONS.include?(candidate[:route][:action])
            :crud
          else
            :included
          end
        end

        # The tool name an operation derives, before any `operationId`.
        #
        # @return [String]
        def derived_name(candidate)
          "#{resource_key(candidate[:route][:controller])}_#{candidate[:route][:action]}"
        end

        private

        def entry_for(candidate)
          status = disposition(candidate)
          legacy = Spree::AgentTools::LegacyTools.names_for(candidate[:verb], candidate[:path])
          return unless status == :included || (legacy.any? && %i[included crud].include?(status))

          operation = candidate[:operation]
          controller = candidate[:route][:controller]
          name = operation['operationId'].presence || derived_name(candidate)
          scope = scope_of(controller)
          read = candidate[:verb] == 'get'
          body = request_body(operation)

          {
            name: name,
            verb: candidate[:verb],
            path: candidate[:path],
            summary: operation['summary'].to_s,
            description: description_for(operation),
            permission: "#{read ? 'read' : 'write'}_#{scope}",
            resource_key: resource_key(controller),
            path_params: candidate[:path].scan(/\{([a-z_]+)\}/).flatten,
            path_descriptions: path_descriptions(operation),
            body_properties: body.fetch('properties', {}),
            body_required: Array(body['required']),
            mutating: !read,
            listed: status == :included,
            legacy_parameters: legacy_parameters(legacy, name),
            legacy_names: legacy
          }
        end

        # A 6.0.0 tool whose name is no longer derived — it pointed at a
        # create, or carried its workflow's name — stays callable through
        # 6.0.x, unlisted, under that name.
        def legacy_entries(entries)
          entries.flat_map do |entry|
            entry[:legacy_names].filter_map do |old|
              next if old == entry[:name] && entry[:listed]

              entry.except(:legacy_names).merge(
                name: old, listed: false, legacy_parameters: Spree::AgentTools::LegacyTools.find(old)[:parameters]
              )
            end
          end
        end

        def legacy_parameters(legacy, name)
          return {} unless legacy.include?(name)

          Spree::AgentTools::LegacyTools.find(name)[:parameters]
        end

        # Two operations deriving one name: the shallower path keeps it, and
        # the contract spec fails so the other gets an `operationId`.
        def resolve_collisions(entries)
          entries.group_by { |entry| entry[:name] }.map do |name, claimants|
            next claimants.first if claimants.one?

            kept = claimants.min_by { |entry| [entry[:path].count('{'), entry[:path].length] }
            Rails.logger.warn("[Spree] agent tool #{name} is derived by #{claimants.size} operations; " \
                              "#{kept[:verb].upcase} #{kept[:path]} keeps it")
            kept
          end
        end

        # The summary, then the description's opening paragraph: what the
        # operation does, in the words its spec already reviews.
        def description_for(operation)
          prose = operation['description'].to_s.gsub(SCOPE_NOTE, '').strip
          paragraph = prose.split(/\n\s*\n/).first.to_s.squish

          [operation['summary'].to_s.strip.delete_suffix('.'), paragraph].compact_blank.join('. ')
        end

        def path_descriptions(operation)
          Array(operation['parameters']).each_with_object({}) do |parameter, result|
            next unless parameter.is_a?(Hash) && parameter['in'] == 'path'

            result[parameter['name']] = parameter['description']
          end
        end

        def request_body(operation)
          schema = operation.dig('requestBody', 'content', 'application/json', 'schema')
          return {} if schema.nil?

          json_schema(AdminDocument.inline(AdminDocument.resolve_schema(schema) || {}))
        end

        # OpenAPI 3.0 marks a nullable field with `nullable: true`; JSON
        # Schema, which a client validates arguments against, says it with a
        # type list.
        def json_schema(schema)
          case schema
          when Array then schema.map { |item| json_schema(item) }
          when Hash
            converted = schema.except('nullable').transform_values { |value| json_schema(value) }
            if schema['nullable'] == true && converted['type'].is_a?(String)
              converted['type'] = [converted['type'], 'null']
            end
            converted
          else schema
          end
        end

        # [verb, OpenAPI path] => the action behind it, from the engine's
        # routes — where an extension's admin routes are drawn too.
        def route_index
          Spree::Core::Engine.routes.routes.each_with_object({}) do |route, index|
            controller_path = route.defaults[:controller].to_s
            next unless controller_path.start_with?('spree/api/v3/admin')

            path = route.path.spec.to_s.sub('(.:format)', '').gsub(/:([a-z_]+)/, '{\1}')
            route.verb.to_s.split('|').each do |verb|
              index[[verb.downcase, path]] ||= { controller: controller_class(controller_path),
                                                 action: route.defaults[:action].to_s }
            end
          end
        end

        def controller_class(controller_path)
          "#{controller_path}_controller".camelize.safe_constantize
        end

        def scope_of(controller)
          controller.try(:_scoped_resource)
        end

        # Controllers whose records carry a live credential — the ones the
        # resource map withholds — offer no tools either: an action on an API
        # key or a webhook endpoint answers with the secret.
        def withheld?(controller)
          model = AgentResourceMap.send(:safely, controller.allocate, :model_class)
          model && AgentResourceMap::WITHHELD_MODELS.include?(model.name)
        end

        def resource_key(controller)
          model = AgentResourceMap.send(:safely, controller.allocate, :model_class)
          model ? model.model_name.element.pluralize : controller.controller_name
        end
      end
    end
  end
end
