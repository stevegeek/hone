# frozen_string_literal: true

require "yaml"

module Hone
  class Config
    CONFIG_FILE = ".hone/config.yml"

    DEFAULTS = {
      harness: {
        warmup_iterations: 10,
        profile_iterations: 100,
        path: ".hone/harness.rb"
      },
      profilers: {
        cpu: "auto",
        memory: false
      },
      output: {
        dir: "tmp/hone"
      },
      analysis: {
        rails: false,
        show_cold: false,
        top: nil
      }
    }.freeze

    def initialize(path = CONFIG_FILE)
      @path = path
      @data = load_config
    end

    def harness
      @data[:harness]
    end

    def profilers
      @data[:profilers]
    end

    def output
      @data[:output]
    end

    def analysis
      @data[:analysis]
    end

    def [](key)
      @data[key.to_sym]
    end

    def exist?
      File.exist?(@path)
    end

    private

    def load_config
      return deep_symbolize(DEFAULTS.dup) unless File.exist?(@path)

      user_config = YAML.safe_load_file(@path, symbolize_names: true) || {}
      deep_merge(DEFAULTS, user_config)
    rescue Psych::SyntaxError => e
      warn "Warning: Invalid config file #{@path}: #{e.message}"
      deep_symbolize(DEFAULTS.dup)
    end

    def deep_merge(base, override)
      result = {}
      base.each do |key, value|
        result[key] = if value.is_a?(Hash) && override[key].is_a?(Hash)
          deep_merge(value, override[key])
        elsif override.key?(key)
          override[key]
        else
          value
        end
      end
      override.each do |key, value|
        result[key] = value unless result.key?(key)
      end
      result
    end

    def deep_symbolize(hash)
      hash.transform_keys(&:to_sym).transform_values do |v|
        v.is_a?(Hash) ? deep_symbolize(v) : v
      end
    end
  end
end
