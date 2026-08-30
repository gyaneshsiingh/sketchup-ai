#!/usr/bin/env ruby
# frozen_string_literal: true

# SketchUp MCP stdio bridge.
# Forwards newline-delimited JSON-RPC (MCP over stdio) from any MCP client
# (opencode, Claude Desktop, …) to the OpenCode Studio plugin's local MCP
# server running inside SketchUp.
#
# Setup (SketchUp must be open, panel plugin loaded, MCP server started via
# the Extensions > OpenCode Studio menu):
#
#   SKETCHUP_MCP_TOKEN=<token from config.json> ruby stdio_proxy.rb
#
# opencode.json example:
#   { "mcp": { "sketchup": { "type": "local",
#       "command": ["ruby", "/path/to/sketchup-plugin/mcp/stdio_proxy.rb"],
#       "environment": { "SKETCHUP_MCP_TOKEN": "..." } } } }

require 'json'
require 'net/http'
require 'uri'

URL = ENV.fetch('SKETCHUP_MCP_URL', 'http://127.0.0.1:8723/mcp')
TOKEN = ENV['SKETCHUP_MCP_TOKEN'].to_s

uri = URI.parse(URL)
http = Net::HTTP.new(uri.host, uri.port)
http.open_timeout = 5
http.read_timeout = 300
headers = { 'Content-Type' => 'application/json' }
headers['Authorization'] = "Bearer #{TOKEN}" unless TOKEN.empty?

$stdout.sync = true

STDIN.each_line do |line|
  line = line.strip
  next if line.empty?

  begin
    req = JSON.parse(line)
  rescue StandardError
    next
  end

  begin
    res = http.post(uri.request_uri, line, headers)
    body = res.body.to_s
    $stdout.puts body unless body.empty? # notifications return empty bodies
  rescue StandardError => e
    if req['id'] # only requests need a response
      $stdout.puts JSON.generate(
        'jsonrpc' => '2.0', 'id' => req['id'],
        'error' => { 'code' => -32_000,
                     'message' => "SketchUp MCP unreachable at #{URL}: #{e.message}. Is SketchUp open with the MCP server started?" }
      )
    end
  end
end
