# frozen_string_literal: true

module Hone
  class Harness
    attr_reader :setup_block, :exercise_block, :teardown_block, :iterations

    def self.load(path)
      raise Hone::Error, "Harness file not found: #{path}" unless File.exist?(path)

      harness = new
      harness.instance_eval(File.read(path), path)
      harness
    end

    def initialize
      @setup_block = nil
      @exercise_block = nil
      @teardown_block = nil
      @iterations = 1
    end

    # Setup block - runs once before profiling (not profiled)
    # Used for loading the application, creating test data, etc.
    def setup(&block)
      @setup_block = block
    end

    # Exercise block - the code to profile
    # @param iterations [Integer] Number of times to run the block during profiling
    def exercise(iterations: 1, &block)
      @iterations = iterations
      @exercise_block = block
    end

    # Teardown block - runs once after profiling (not profiled)
    # Used for cleanup, closing connections, etc.
    def teardown(&block)
      @teardown_block = block
    end

    def run_setup
      @setup_block&.call
    end

    def run_exercise
      @exercise_block&.call
    end

    def run_teardown
      @teardown_block&.call
    end

    def valid?
      !@exercise_block.nil?
    end
  end
end
