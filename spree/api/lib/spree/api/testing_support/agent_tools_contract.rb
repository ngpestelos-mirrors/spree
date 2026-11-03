require 'spree/api/testing_support/agent_tools'

# The contract between an engine's admin endpoints and the agent tools built
# from them. Core includes it, and so does every extension that adds admin
# endpoints:
#
#   require 'spree/api/testing_support/agent_tools_contract'
#
#   RSpec.describe 'agent tools' do
#     it_behaves_like 'an engine whose admin writes are agent tools', MyExtension::Engine
#   end
#
# An admin write cannot land without an operation describing it, an opt-out
# without its reason, or two operations claiming one tool name.
#
# See docs/plans/6.0-agent-tools-from-openapi.md.
RSpec.shared_examples 'an engine whose admin writes are agent tools' do |engine|
  operations = Spree::Api::AgentOperations

  # The admin routes this engine's own controllers serve.
  let(:engine_candidates) do
    root = engine.root.to_s
    operations.candidates.select do |candidate|
      controller = candidate.dig(:route, :controller)
      location = controller && Object.const_source_location(controller.name)&.first
      location&.start_with?(root)
    end
  end

  let(:engine_routes) do
    root = engine.root.to_s
    Spree::Core::Engine.routes.routes.filter_map do |route|
      controller_path = route.defaults[:controller].to_s
      next unless controller_path.start_with?('spree/api/v3/admin')

      verb = route.verb.to_s.downcase
      action = route.defaults[:action].to_s
      next unless operations::WRITE_VERBS.include?(verb) && !operations::CRUD_ACTIONS.include?(action)

      controller = "#{controller_path}_controller".camelize.safe_constantize
      location = controller && Object.const_source_location(controller.name)&.first
      next unless location&.start_with?(root)

      [verb, route.path.spec.to_s.sub('(.:format)', '').gsub(/:([a-z_]+)/, '{\1}')]
    end.uniq
  end

  # The tool name each listed action derives, before collisions are settled.
  let(:included_names) do
    engine_candidates.select { |candidate| operations.disposition(candidate) == :included }.map do |candidate|
      candidate[:operation]['operationId'].presence || operations.derived_name(candidate)
    end
  end

  it 'documents every admin action its controllers serve' do
    paths = Spree::Api::AdminDocument.document['paths'] || {}
    undocumented = engine_routes.reject { |verb, path| paths.dig(path, verb) }.
                   map { |verb, path| "#{verb.upcase} #{path}" }

    expect(undocumented).to be_empty, <<~MESSAGE
      These admin actions have no operation in the engine's OpenAPI document, so no
      agent tool and no API reference describes them:

        #{undocumented.join("\n  ")}

      Write an rswag integration spec for each, then regenerate the document.
    MESSAGE
  end

  it 'gives every opt-out a reason' do
    unexplained = engine_candidates.filter_map do |candidate|
      operation = candidate[:operation]
      next unless operation[operations::AGENT_KEY] == false && operation[operations::REASON_KEY].blank?

      "#{candidate[:verb].upcase} #{candidate[:path]}"
    end

    expect(unexplained).to be_empty
  end

  it 'derives a distinct tool name for every action' do

    duplicated = included_names.tally.select { |_name, count| count > 1 }.keys
    expect(duplicated).to be_empty, "Give these operations an operationId: #{duplicated.join(', ')}"
  end

  it 'names every tool the way MCP accepts' do
    invalid = Spree::AgentTools::OperationCatalog.entries_with_aliases.map(&:name).
              reject { |name| name.match?(/\A[a-zA-Z0-9_-]{1,64}\z/) }

    expect(invalid).to be_empty
  end

  it 'gives every tool a summary and a permission the catalog knows' do

    faults = included_names.filter_map do |name|
      entry = Spree::AgentTools::OperationCatalog.find(name)
      next "#{name}: not registered" if entry.nil?
      next "#{name}: no summary" if entry.summary.blank?

      "#{name}: unknown permission #{entry.permission}" unless Spree.permissions.key?(entry.permission)
    end

    expect(faults).to be_empty
  end
end
