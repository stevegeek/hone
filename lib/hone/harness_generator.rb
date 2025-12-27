# frozen_string_literal: true

require "fileutils"

module Hone
  class HarnessGenerator
    HARNESS_DIR = ".hone"
    HARNESS_FILE = "harness.rb"

    def initialize(rails: false)
      @rails = rails
    end

    def generate
      FileUtils.mkdir_p(HARNESS_DIR)

      path = File.join(HARNESS_DIR, HARNESS_FILE)

      if File.exist?(path)
        puts "Harness already exists: #{path}"
        puts "Delete it first if you want to regenerate."
        return false
      end

      template = @rails ? rails_template : ruby_template
      File.write(path, template)

      puts "Created #{path}"
      puts
      puts "Next steps:"
      puts "  1. Edit #{path} to exercise your application's hot paths"
      puts "  2. Run: hone profile"
      puts "  3. Run: hone analyze ."
      puts

      true
    end

    private

    def ruby_template
      <<~RUBY
        # frozen_string_literal: true

        # Hone Performance Harness
        # ========================
        # This file defines how to exercise your code for profiling.
        #
        # Run with: hone profile
        # Analyze:  hone analyze . (uses generated profiles automatically)

        # Setup: Load your application (not profiled)
        setup do
          # Load your library or application
          # require_relative "../lib/my_gem"

          # Create any test data needed
          # @data = generate_test_data
        end

        # Exercise: The code to profile
        # This block runs multiple times during profiling.
        # Put your realistic workload here.
        exercise iterations: 100 do
          # Example: Call your hot methods
          # result = MyClass.new(@data).process
          #
          # Example: Simulate typical usage
          # parser = Parser.new
          # 100.times { parser.parse(sample_input) }
        end

        # Teardown: Cleanup (not profiled)
        teardown do
          # Close connections, clean up temp files, etc.
        end
      RUBY
    end

    def rails_template
      <<~RUBY
        # frozen_string_literal: true

        # Hone Performance Harness (Rails)
        # =================================
        # This file defines how to exercise your Rails app for profiling.
        #
        # Run with: hone profile
        # Analyze:  hone analyze app/ (uses generated profiles automatically)

        # Setup: Boot Rails (not profiled)
        setup do
          require_relative "../config/environment"
          Rails.application.eager_load!

          # Create test data if needed
          # @user = User.first || User.create!(name: "Test", email: "test@example.com")
          # @items = Item.limit(10).to_a
        end

        # Exercise: Your hot paths
        # This block runs multiple times during profiling.
        # Replace with YOUR app's actual hot code paths.
        exercise iterations: 100 do
          # Example: Model queries
          # User.where(active: true).includes(:orders).limit(10).to_a

          # Example: Business logic
          # Order.new(user: @user, items: @items).calculate_total

          # Example: Service objects
          # PaymentProcessor.new(order).validate

          # Example: Simulate a controller action
          # app = Rails.application
          # env = Rack::MockRequest.env_for("/users/1")
          # app.call(env)
        end

        # Teardown: Cleanup (not profiled)
        teardown do
          # Clean up test data if needed
          # @user&.destroy
        end
      RUBY
    end
  end
end
