require 'json'

module Pranjali
  module OpenCodeStudio
    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are an expert interior design automation agent working INSIDE SketchUp
      via the "OpenCode Studio" plugin. You execute design tasks by calling tools.

      Rules:
      - All coordinates and dimensions are in METERS. Origin is the room corner, z is up.
      - Start complex tasks with query_scene to inspect the model.
      - Build rooms with create_room, then place furniture with place_component
        (uses components already in the model) or create_box for generic solids.
      - Place furniture sensibly: sofas against walls, beds centered on the wall
        opposite the door, clear walkways of at least 0.75 m, etc.
      - Use apply_color for finishes (user must select faces first).
      - Work step by step; prefer many small, safe operations over one risky one.
      - When finished, reply with a short summary of what you built and any advice.
    PROMPT

    # The agentic loop: model -> tool calls -> SketchUp -> model -> ...
    class Agent
      MAX_STEPS = 15

      def initialize(config, runner, mcp_manager, log)
        @config = config
        @runner = runner
        @mcp = mcp_manager
        @log = log
        @client = ApiClient.new(config)
        @stop = false
        @running = false
      end

      def running?
        @running
      end

      def stop!
        @stop = true
      end

      def run_async(prompt)
        return if @running
        @stop = false
        @running = true
        Thread.new do
          begin
            run(prompt)
          rescue StandardError => e
            @log.call("Task failed: #{e.message}", 'error')
          ensure
            @running = false
            @log.call('__done__', 'state')
          end
        end
      end

      def run(prompt)
        tools = @mcp.merged_definitions(DesignTools.definitions)
        messages = [
          { 'role' => 'system', 'content' => SYSTEM_PROMPT },
          { 'role' => 'user', 'content' => prompt }
        ]

        @log.call("Task: #{prompt}", 'user')
        step = 0
        while step < MAX_STEPS
          break if @stop
          step += 1
          @log.call("Step #{step}: thinking...", 'info')
          msg = @client.chat(messages, tools)
          messages << msg

          calls = msg['tool_calls']
          if calls.nil? || calls.empty?
            @log.call(msg['content'].to_s, 'assistant')
            return
          end

          calls.each do |c|
            break if @stop
            name = c.dig('function', 'name').to_s
            raw = c.dig('function', 'arguments').to_s
            args = parse_args(raw)
            @log.call("-> #{name} #{truncate(raw, 160)}", 'tool')
            result = execute(name, args)
            @log.call(truncate(result.to_s, 400), 'tool_result')
            messages << { 'role' => 'tool', 'tool_call_id' => c['id'], 'content' => result.to_s }
          end
        end
        @log.call(@stop ? 'Task stopped.' : 'Reached max steps; stopping.', 'info')
      end

      private

      def execute(name, args)
        if @mcp.builtin_call?(name)
          @runner.sync { DesignTools.call(name, args) }
        else
          @mcp.call(name, args)
        end
      end

      def parse_args(raw)
        JSON.parse(raw)
      rescue StandardError
        {}
      end

      def truncate(s, n)
        s = s.to_s
        s.length <= n ? s : s[0, n] + '…'
      end
    end
  end
end
