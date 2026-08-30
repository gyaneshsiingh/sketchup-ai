# Loader for OpenCode Studio - AI design automation for SketchUp.
# InteriorByPranjali (c) 2026
require 'sketchup.rb'
require 'extensions.rb'

module Pranjali
  module OpenCodeStudio
    PLUGIN_ROOT = File.dirname(__FILE__).freeze

    extension = SketchupExtension.new('OpenCode Studio', File.join(PLUGIN_ROOT, 'opencode_studio', 'main'))
    extension.description = 'AI-powered interior design automation. Uses an agentic tool loop (OpenAI-compatible API, e.g. OpenCode Zen) plus optional MCP servers to build rooms, place furniture and apply materials from plain-language tasks.'
    extension.version = '1.0.0'
    extension.creator = 'InteriorByPranjali'
    extension.copyright = "2026 #{extension.creator}"
    Sketchup.register_extension(extension, true)
  end
end
