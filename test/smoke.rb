# Smoke test: runs the pure-Ruby parts (config, tool schemas, API body
# building, MCP merging) without SketchUp installed.
#   ruby test/smoke.rb
require 'json'

HERE = File.expand_path(__dir__)
PLUGIN = File.join(HERE, '..', 'opencode_studio')

# Minimal SketchUp stubs so modules load outside SketchUp.
module Sketchup
end

require File.join(PLUGIN, 'version')
require File.join(PLUGIN, 'config')
require File.join(PLUGIN, 'api_client')
require File.join(PLUGIN, 'mcp_client')
require File.join(PLUGIN, 'main_thread')
require File.join(PLUGIN, 'design_tools')
require File.join(PLUGIN, 'furniture_tools')
require File.join(PLUGIN, 'mcp_server')
require File.join(PLUGIN, 'agent')

$failures = []

def check(label, cond)
  if cond
    puts "PASS  #{label}"
  else
    $failures << label
    puts "FAIL  #{label}"
  end
end

# 1. Tool registry is valid OpenAI tool schema
defs = Pranjali::OpenCodeStudio::DesignTools.definitions
check('definitions non-empty', defs.length >= 10)
check('definitions well-formed', defs.all? { |d| d[:type] == 'function' && d[:function][:name].is_a?(String) && d[:function][:parameters].is_a?(Hash) })

# 2. Config defaults
cfg = Pranjali::OpenCodeStudio::Config.new
check('default base_url is opencode zen', cfg['base_url'] == 'https://opencode.ai/zen/v1')
check('default model set', !cfg['model'].to_s.empty?)

# 3. API request body building
body = Pranjali::OpenCodeStudio::ApiClient.build_body('m1', [{ 'role' => 'user', 'content' => 'hi' }], defs)
check('body has model', body['model'] == 'm1')
check('body has tools', body['tools'].is_a?(Array))
empty = Pranjali::OpenCodeStudio::ApiClient.build_body('m1', [], [])
check('body omits empty tools', !empty.key?('tools'))

# 4. Agent tool dispatch falls back gracefully outside SketchUp
result = Pranjali::OpenCodeStudio::DesignTools.call('no_such_tool', {})
check('unknown tool error string', result.start_with?('ERROR'))

# 5. MCP manager with zero servers returns built-ins unchanged
mgr = Pranjali::OpenCodeStudio::McpManager.new(cfg)
merged = mgr.merged_definitions(defs)
check('no mcp => unchanged', merged.length == defs.length)
check('builtin_call? true', mgr.builtin_call?('create_room'))

# 6. Furniture kit + extended skills merged into the registry
names = Pranjali::OpenCodeStudio::DesignTools.definitions.map { |d| d[:function][:name] }
check('furniture skills merged', %w[create_bed create_sofa create_table create_wardrobe create_tv_unit create_wall auto_layout style_palette duplicate_object resize_group select_by_name list_components].all? { |n| names.include?(n) })
bed_def = Pranjali::OpenCodeStudio::DesignTools.definitions.find { |d| d[:function][:name] == 'create_bed' }
check('create_bed requires position', bed_def[:function][:parameters]['required'] == %w[x_m y_m])
check('layout rooms known', Pranjali::OpenCodeStudio::FurnitureTools::LAYOUTS.keys.sort == %w[bedroom dining living])
check('palettes known', Pranjali::OpenCodeStudio::FurnitureTools::STYLES.keys.length >= 5)

# 7. Local SketchUp MCP server: JSON-RPC handling
srv = Pranjali::OpenCodeStudio::McpServer.new(cfg, nil)
r = JSON.parse(srv.send(:handle_rpc, { 'jsonrpc' => '2.0', 'id' => 1, 'method' => 'initialize' }))
check('mcp initialize', r['result']['serverInfo']['name'] == 'sketchup-mcp')
r = JSON.parse(srv.send(:handle_rpc, { 'jsonrpc' => '2.0', 'id' => 2, 'method' => 'tools/list' }))
check('mcp tools/list exposes all skills', r['result']['tools'].length == names.length && r['result']['tools'].first['inputSchema'].is_a?(Hash))
r = JSON.parse(srv.send(:handle_rpc, { 'jsonrpc' => '2.0', 'id' => 3, 'method' => 'nope' }))
check('mcp unknown method error', r['error']['code'] == -32_601)
check('mcp notification => empty body', srv.send(:handle_rpc, { 'jsonrpc' => '2.0', 'method' => 'notifications/initialized' }) == '')

if $failures.empty?
  puts "\nSMOKE OK"
else
  puts "\n#{$failures.length} failure(s): #{$failures.join(', ')}"
  exit 1
end
