require 'json'
require 'fileutils'

module Pranjali
  module OpenCodeStudio
    # Persistent settings. Stored as JSON in the user's app-data directory.
    # NOTE: the API key is stored in plain text (standard practice for
    # desktop tools); the file is only readable by the current user.
    class Config
      DEFAULTS = {
        'api_key' => '',
        'base_url' => 'https://opencode.ai/zen/v1',
        'model' => 'grok-code-fast-1',
        'mcp_servers' => [] # [{ 'name' => '..', 'url' => '..', 'headers' => {} }]
      }.freeze

      attr_reader :path

      def initialize
        base_dir = ENV['APPDATA'] || File.expand_path('~/Library/Application Support')
        @dir = File.join(base_dir, 'OpenCodeStudio')
        @path = File.join(@dir, 'config.json')
        @data = DEFAULTS.merge(load)
      end

      def [](key)
        @data[key] || DEFAULTS[key]
      end

      def []=(key, value)
        @data[key] = value
        save
      end

      def api_key
        self['api_key'].to_s
      end

      def configured?
        !api_key.empty?
      end

      def mcp_servers
        self['mcp_servers'] || []
      end

      def to_public_hash
        {
          'configured' => configured?,
          'base_url' => self['base_url'],
          'model' => self['model'],
          'mcp_count' => mcp_servers.size
        }
      end

      def save
        FileUtils.mkdir_p(@dir)
        FileUtils.chmod(0o700, @dir) rescue nil
        File.write(@path, JSON.pretty_generate(@data))
        FileUtils.chmod(0o600, @path) rescue nil
        true
      rescue StandardError
        false
      end

      private

      def load
        return {} unless File.exist?(@path)
        JSON.parse(File.read(@path))
      rescue StandardError
        {}
      end
    end
  end
end
