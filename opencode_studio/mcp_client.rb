require 'json'
require 'net/http'
require 'uri'

module Pranjali
  module OpenCodeStudio
    # Best-effort MCP (Model Context Protocol) client over streamable HTTP.
    # Supports servers that answer JSON-RPC POSTs with JSON or SSE frames.
    class McpClient
      attr_reader :name, :url

      def initialize(name, url, headers = {})
        @name = name
        @url = url
        @headers = headers || {}
        @id = 0
        @initialized = false
      end

      def tools
        init!
        rpc('tools/list', {})['tools'] || []
      rescue StandardError => e
        raise "MCP '#{@name}' tools/list failed: #{e.message}"
      end

      def call(tool_name, arguments)
        init!
        r = rpc('tools/call', 'name' => tool_name, 'arguments' => arguments || {})
        if r.is_a?(Hash) && r.key?('content')
          (r['content'] || []).map { |c| c['text'] }.compact.join("\n")
        else
          r.inspect
        end
      rescue StandardError => e
        "ERROR: #{e.message}"
      end

      private

      def init!
        return if @initialized
        rpc('initialize', {
              'protocolVersion' => '2024-11-05',
              'capabilities' => {},
              'clientInfo' => { 'name' => 'opencode-studio', 'version' => Pranjali::OpenCodeStudio::VERSION }
            })
        notify('notifications/initialized')
        @initialized = true
      end

      def notify(method)
        body = { 'jsonrpc' => '2.0', 'method' => method }
        post_json(body)
      end

      def rpc(method, params)
        @id += 1
        res = post_json('jsonrpc' => '2.0', 'id' => @id, 'method' => method, 'params' => params)
        parsed = extract_json(res)
        raise parsed['error']['message'] if parsed.is_a?(Hash) && parsed['error']
        parsed['result']
      end

      def extract_json(res)
        ct = res['content-type'].to_s
        text = res.body.to_s
        if ct.include?('event-stream') || text.lstrip.start_with?('event:', 'data:')
          lines = text.lines.select { |l| l.start_with?('data:') }
          raise 'MCP server sent empty SSE response' if lines.empty?
          JSON.parse(lines.last.sub(/\Adata:\s?/, ''))
        else
          JSON.parse(text)
        end
      end

      def post_json(body)
        uri = URI.parse(@url)
        h = Net::HTTP.new(uri.host, uri.port)
        h.use_ssl = uri.scheme == 'https'
        h.open_timeout = 10
        h.read_timeout = 60
        headers = {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json, text/event-stream'
        }.merge(@headers)
        res = h.post(uri.request_uri, JSON.generate(body), headers)
        raise "MCP '#{@name}' HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)
        res
      end
    end

    # Loads configured MCP servers, merges their tools with the built-in ones
    # and routes tool calls to the right client.
    class McpManager
      attr_reader :clients, :tool_map

      def initialize(config)
        @clients = config.mcp_servers.map do |s|
          McpClient.new(s['name'], s['url'], s['headers'])
        end
        @tool_map = {} # openai_name => { client:, schema: }
      end

      # builtin: array of OpenAI tool defs for built-in skills.
      # Returns merged OpenAI tool defs and populates the routing map.
      def merged_definitions(builtin)
        defs = builtin.dup
        used = builtin.map { |d| d[:function][:name] }.to_h { |n| [n, true] }
        @clients.each do |client|
          client.tools.each do |t|
            name = t['name'].to_s
            next if name.empty?
            route_name = used[name] ? "#{client.name}__#{name}" : name
            used[route_name] = true
            schema = t['inputSchema'] || { 'type' => 'object', 'properties' => {} }
            defs << { type: 'function', function: { name: route_name, description: "[MCP:#{client.name}] #{t['description']}", parameters: schema } }
            @tool_map[route_name] = { client: client, name: name }
          end
        rescue StandardError => e
          defs << { type: 'function', function: { name: "mcp_status_#{client.name}", description: "Reports why MCP server '#{client.name}' is unavailable.", parameters: { 'type' => 'object', 'properties' => {} } } }
          @tool_map["mcp_status_#{client.name}"] = { error: e.message }
        end
        defs
      end

      def builtin_call?(name)
        !@tool_map.key?(name)
      end

      def call(name, args)
        entry = @tool_map[name]
        return "ERROR: unknown MCP tool #{name}" unless entry
        return "ERROR: MCP server unavailable: #{entry[:error]}" if entry[:error]

        entry[:client].call(entry[:name], args)
      end
    end
  end
end
