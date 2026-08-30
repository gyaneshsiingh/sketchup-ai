require 'thread'

module Pranjali
  module OpenCodeStudio
    # SketchUp requires model edits + UI calls on the main thread.
    # HTTP happens on background threads; work items are marshalled back here.
    class MainThreadRunner
      def initialize
        @queue = Queue.new
        @started = false
      end

      def start_timer_fallback
        return if @started || !defined?(UI) || !defined?(UI.start_timer)
        @started = true
        UI.start_timer(0.05, true) do
          drain!
        end
      end

      def schedule(&block)
        if defined?(Sketchup::PostScheduledTask)
          Sketchup::PostScheduledTask.add(&block)
        elsif @started
          @queue << block
        else
          block.call
        end
      end

      # Runs block on the main thread and blocks the caller until done.
      def sync(&block)
        return block.call if on_main_thread?
        q = Queue.new
        schedule do
          q << (begin
            block.call
          rescue StandardError => e
            e
          end)
        end
        result = q.pop
        raise result if result.is_a?(StandardError)
        result
      end

      private

      def drain!
        loop do
          block = begin
            @queue.pop(true)
          rescue ThreadError
            break
          end
          block.call
        end
      rescue StandardError
          # keep the timer alive even if a task raised
      end

      def on_main_thread?
        return true unless defined?(Sketchup)
        false
      end
    end
  end
end
