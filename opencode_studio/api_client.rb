require 'json'
require 'net/http'
require 'uri'

module Pranjali
  module OpenCodeStudio
    # Minimal client for any OpenAI-compatible /chat/completions endpoint
    # with tool calling (default: OpenCode Zen).
    class ApiClient
      attr_reader :config

      def initialize(config)
        @config = config
      end

      # Returns array of { 'id' =>, 'name' => } models.
      def models
        uri = URI.join(base_url.chomp('/'), 'models')
        res = get(uri)
        data = parse(res)['data'] || []
        data.map { |m| { 'id' => m['id'], 'name' => m['name'] || m['id'] } }
      end

      # messages: OpenAI message array. tools: OpenAI tools array.
      # Returns the assistant message hash.
      def chat(messages, tools)
        body = self.class.build_body(@config['model'], messages, tools)
        res = post(chat_uri, body)
        parse(res).dig('choices', 0, 'message') || {}
      end

      def chat_uri
        URI.join(base_url.chomp('/'), 'chat/completions')
      end

      def self.build_body(model, messages, tools)
        body = {
          'model' => model,
          'messages' => messages,
          'temperature' => 0.2
        }
        body['tools'] = tools unless tools.nil? || tools.empty?
        body
      end

      private

      def base_url
        @config['base_url'].to_s
      end

      def headers
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@config.api_key}"
        }
      end

      def get(uri)
        http(uri).get(uri.request_uri, headers)
      end

      def post(uri, body)
        http(uri).post(uri.request_uri, JSON.generate(body), headers)
      end

      def http(uri)
        h = Net::HTTP.new(uri.host, uri.port)
        h.use_ssl = uri.scheme == 'https'
        h.open_timeout = 15
        h.read_timeout = 180
        h
      end

      def parse(res)
        unless res.is_a?(Net::HTTPSuccess)
          raise "API error #{res.code}: #{res.body.to_s[0, 300]}"
        end
        JSON.parse(res.body)
      end
    end
  end
end
