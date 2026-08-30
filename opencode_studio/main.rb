require 'sketchup.rb'

module Pranjali
  module OpenCodeStudio
    PLUGIN_ROOT = File.expand_path('..', __dir__).freeze unless defined?(PLUGIN_ROOT)

    require File.join(PLUGIN_ROOT, 'opencode_studio', 'version')
    require File.join(PLUGIN_ROOT, 'opencode_studio', 'config')
    require File.join(PLUGIN_ROOT, 'opencode_studio', 'api_client')
    require File.join(PLUGIN_ROOT, 'opencode_studio', 'mcp_client')
    require File.join(PLUGIN_ROOT, 'opencode_studio', 'main_thread')
    require File.join(PLUGIN_ROOT, 'opencode_studio', 'design_tools')
    require File.join(PLUGIN_ROOT, 'opencode_studio', 'agent')
    require File.join(PLUGIN_ROOT, 'opencode_studio', 'dialog')

    CONFIG = Config.new
    RUNNER = MainThreadRunner.new
    DIALOG = Dialog.new(CONFIG, RUNNER)

    RUNNER.start_timer_fallback

    module_function

    def show_panel
      DIALOG.show
    end

    unless defined?(@loaded)
      @loaded = true
      menu = UI.menu('Extensions').add_submenu('OpenCode Studio')
      menu.add_item('Open Panel') { show_panel }

      toolbar = UI::Toolbar.new('OpenCode Studio')
      cmd = UI::Command.new('Open Panel') { show_panel }
      cmd.tooltip = 'OpenCode Studio — AI Design Automation'
      cmd.status_bar_text = 'Opens the AI design automation panel'
      cmd.menu_text = 'Open Panel'
      toolbar.add_item(cmd)
      toolbar.restore
    end
  end
end
