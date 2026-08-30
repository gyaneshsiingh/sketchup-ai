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
require File.join(PLUGIN, 'design_tools')
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

if $failures.empty?
  puts "\nSMOKE OK"
else
  puts "\n#{$failures.length} failure(s): #{$failures.join(', ')}"
  exit 1
end
