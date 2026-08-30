require 'json'

module Pranjali
  module OpenCodeStudio
    # The modern HTML panel: settings (API key etc.), chat log, task input.
    class Dialog
      HTML_DIR = File.join(PLUGIN_ROOT, 'html') unless defined?(HTML_DIR)

      def initialize(config, runner)
        @config = config
        @runner = runner
        @agent = nil
        @dialog = nil
      end

      def show
        ensure_dialog
        if @dialog.visible?
          @dialog.bring_to_front
        else
          @dialog.show
        end
        push_state
      end

      def log(message, kind = 'info')
        return unless @dialog
        args = [kind, message.to_s].map { |s| JSON.generate(s) }.join(',')
        @dialog.execute_script("window.appendLog(#{args});")
      rescue StandardError
          # dialog may be closed mid-task
      end

      def push_state
        return unless @dialog
        payload = JSON.generate(@config.to_public_hash)
        @dialog.execute_script("window.setState(#{payload});")
      end

      private

      def ensure_dialog
        return if @dialog
        @dialog = UI::HtmlDialog.new(
          dialog_title: 'OpenCode Studio — AI Design Automation',
          preferences_key: 'opencode_studio',
          width: 420, height: 640, left: 100, top: 100,
          resizable: true,
          style: :utility
        )
        @dialog.set_file(File.join(HTML_DIR, 'index.html'))
        register_callbacks
        @dialog.set_on_closed { @agent&.stop! }
      end

      def register_callbacks
        @dialog.add_action_callback('ready') { |_ctx| push_state }

        @dialog.add_action_callback('save_settings') do |_ctx, api_key, base_url, model|
          @config['api_key'] = api_key.to_s.strip
          @config['base_url'] = base_url.to_s.strip unless base_url.to_s.strip.empty?
          @config['model'] = model.to_s.strip unless model.to_s.strip.empty?
          log('Settings saved. Key stored locally on this machine.', 'ok')
          push_state
        end

        @dialog.add_action_callback('fetch_models') do |_ctx|
          Thread.new do
            begin
              list = ApiClient.new(@config).models
              payload = JSON.generate(list)
              @dialog.execute_script("window.setModels(#{payload});")
              log("Found #{list.length} models.", 'ok')
            rescue StandardError => e
              log("Could not list models: #{e.message}", 'error')
            end
          end
        end

        @dialog.add_action_callback('send_task') do |_ctx, prompt|
          prompt = prompt.to_s.strip
          next if prompt.empty?
          if !@config.configured?
            log('Set your API key first (Settings section).', 'error')
          elsif @agent&.running?
            log('A task is already running — press Stop first.', 'error')
          else
            mcp = McpManager.new(@config)
            @agent = Agent.new(@config, @runner, mcp, ->(m, k) { log(m, k) })
            @agent.run_async(prompt)
            push_running(true)
          end
          nil
        end

        @dialog.add_action_callback('stop_task') do |_ctx|
          @agent&.stop!
          log('Stop requested…', 'info')
        end
      end

      def push_running(flag)
        return unless @dialog
        @dialog.execute_script("window.setRunning(#{flag ? 'true' : 'false'});")
      end
    end
  end
end
