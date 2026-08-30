require 'json'
require 'socket'
require 'securerandom'

module Pranjali
  module OpenCodeStudio
    # Local MCP (Model Context Protocol) server that exposes SketchUp as tools.
    # - Streamable-HTTP transport: POST http://127.0.0.1:<port>/mcp (JSON-RPC 2.0)
    # - GET /health for status
    # - Bearer token auth (config['mcp_token'], auto-generated on first start)
    # All tool execution is marshalled to SketchUp's main thread.
    class McpServer
      PROTOCOL_VERSION = '2024-11-05'

      attr_reader :port

      def initialize(config, runner)
        @config = config
        @runner = runner
        @server = nil
        @thread = nil
      end

      def running?
        !!@server
      end

      def url
        "http://127.0.0.1:#{@port}/mcp"
      end

      def token
        @config['mcp_token'].to_s
      end

      def start
        return self if running?
        ensure_token
        @port = @config['mcp_server_port'].to_i.nonzero? || 8723
        @server = TCPServer.new('127.0.0.1', @port)
        @thread = Thread.new { accept_loop }
        self
      rescue StandardError => e
        @server = nil
        raise "MCP server failed to start on port #{@port}: #{e.message}"
      end

      def stop
        srv = @server
        @server = nil
        srv&.close
        true
      rescue StandardError
        false
      end

      private

      def ensure_token
        return unless @config['mcp_token'].to_s.empty?
        @config['mcp_token'] = SecureRandom.hex(16)
      end

      def accept_loop
        loop do
          client = @server.accept
          Thread.new(client) { |c| handle(c) }
        end
      rescue StandardError
        # @server was closed by #stop
      end

      def handle(client)
        request_line = client.gets
        return unless request_line
        verb, path = request_line.split(' ')
        content_length = 0
        authorization = nil
        loop do
          line = client.gets
          break if line.nil? || line.strip.empty?
          key, value = line.split(':', 2)
          key = key.strip.downcase
          authorization = value.strip if key == 'authorization'
          content_length = value.strip.to_i if key == 'content-length'
        end

        route = [verb, path.to_s.split('?').first]
        if verb == 'OPTIONS'
          respond(client, 204, '')
        elsif route == ['GET', '/health']
          respond(client, 200, JSON.generate(status: 'ok', server: 'sketchup-mcp', version: VERSION))
        elsif route == ['POST', '/mcp']
          return respond(client, 401, JSON.generate(error: 'unauthorized: bad or missing bearer token')) unless authorized?(authorization)
          body = content_length.positive? ? client.read(content_length) : ''
          parsed = begin
            JSON.parse(body)
          rescue StandardError
            nil
          end
          respond(client, 200, handle_rpc(parsed))
        else
          respond(client, 404, JSON.generate(error: 'not found'))
        end
      rescue StandardError => e
        respond(client, 500, JSON.generate(error: e.message)) rescue nil
      ensure
        client&.close
      end

      def authorized?(authorization)
        token.empty? || authorization == "Bearer #{token}"
      end

      def respond(client, code, body)
        reason = { 200 => 'OK', 202 => 'Accepted', 204 => 'No Content', 401 => 'Unauthorized', 404 => 'Not Found', 500 => 'Internal Server Error' }[code] || 'Error'
        headers = [
          "HTTP/1.1 #{code} #{reason}",
          'Content-Type: application/json',
          "Content-Length: #{body.bytesize}",
          'Connection: close',
          'Access-Control-Allow-Origin: *',
          'Access-Control-Allow-Headers: Content-Type, Authorization, MCP-Session-Id',
          'Access-Control-Allow-Methods: GET, POST, OPTIONS'
        ]
        client.write(headers.join("\r\n") + "\r\n\r\n" + body)
      rescue StandardError
        nil
      end

      # ---- JSON-RPC ----

      def handle_rpc(req)
        return rpc_error(nil, -32_700, 'Parse error') unless req.is_a?(Hash)

        id = req['id']
        method = req['method'].to_s
        return '' if id.nil? # notification: empty 202-style body

        result =
          case method
          when 'initialize'
            {
              'protocolVersion' => PROTOCOL_VERSION,
              'capabilities' => { 'tools' => {} },
              'serverInfo' => { 'name' => 'sketchup-mcp', 'version' => VERSION }
            }
          when 'ping'
            {}
          when 'tools/list'
            { 'tools' => tools_json }
          when 'tools/call'
            name = req.dig('params', 'name').to_s
            args = req.dig('params', 'arguments') || {}
            begin
              text = @runner.sync { DesignTools.call(name, args) }
              { 'content' => [{ 'type' => 'text', 'text' => text.to_s }],
                'isError' => text.to_s.start_with?('ERROR') }
            rescue StandardError => e
              { 'content' => [{ 'type' => 'text', 'text' => "ERROR: #{e.message}" }], 'isError' => true }
            end
          else
            return rpc_error(id, -32_601, "Method not found: #{method}")
          end
        JSON.generate('jsonrpc' => '2.0', 'id' => id, 'result' => result)
      end

      def tools_json
        DesignTools.definitions.map do |d|
          fn = d[:function]
          { 'name' => fn[:name], 'description' => fn[:description], 'inputSchema' => fn[:parameters] }
        end
      end

      def rpc_error(id, code, message)
        JSON.generate('jsonrpc' => '2.0', 'id' => id, 'error' => { 'code' => code, 'message' => message })
      end
    end
  end
end
