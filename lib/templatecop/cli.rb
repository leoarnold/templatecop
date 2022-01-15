# frozen_string_literal: true

require 'optparse'
require 'rubocop'

module Templatecop
  # Call this from your executable.
  # @example
  #   Templatecop.call(
  #     default_configuration_path: File.expand_path('../default.yml', __dir__),
  #     executable_name: 'slimcop',
  #     ruby_extractor: Slimcop::RubyExtractor.new,
  #     user_configuration_paths: %w[.slimcop.yml .rubocop.yml]
  #   )
  class Cli
    class << self
      # @param [Array<String>] argv
      # @param [String] default_configuration_path (e.g. "default.yml")
      # @param [Array<String>] default_path_patterns
      # @param [String] executable_name (e.g. "slimcop")
      # @param [#call] ruby_extractor An object that converts template code into Ruby codes.
      # @param [Array<String>] user_configuration_paths
      def call(
        executable_name:,
        ruby_extractor:,
        user_configuration_paths:,
        argv: ::ARGV,
        default_configuration_path: nil,
        default_path_patterns: []
      )
        new(
          argv: argv,
          default_configuration_path: default_configuration_path,
          default_path_patterns: default_path_patterns,
          executable_name: executable_name,
          ruby_extractor: ruby_extractor,
          user_configuration_paths: user_configuration_paths
        ).call
      end
    end

    def initialize(
      argv:,
      default_configuration_path:,
      default_path_patterns:,
      executable_name:,
      ruby_extractor:,
      user_configuration_paths:
    )
      @argv = argv
      @default_configuration_path = default_configuration_path
      @default_path_patterns = default_path_patterns
      @executable_name = executable_name
      @ruby_extractor = ruby_extractor
      @user_configuration_paths = user_configuration_paths
    end

    def call
      options = parse_options!
      formatter = ::RuboCop::Formatter::ProgressFormatter.new($stdout, color: options[:color])
      rubocop_config = RuboCopConfigGenerator.new(
        default_configuration_path: @default_configuration_path,
        user_configuration_paths: ([options[:additional_config_file_path]] + @user_configuration_paths).compact
      ).call
      file_paths = PathFinder.new(
        default_patterns: @default_path_patterns,
        patterns: @argv
      ).call

      offenses = Runner.new(
        auto_correct: options[:auto_correct],
        file_paths: file_paths,
        formatter: formatter,
        rubocop_config: rubocop_config,
        ruby_extractor: @ruby_extractor
      ).call

      exit(offenses.empty? ? 0 : 1)
    end

    private

    # @return [Hash]
    def parse_options!
      options = {}
      parser = ::OptionParser.new
      parser.banner = "Usage: #{@executable_name} [options] [file1, file2, ...]"
      parser.version = VERSION
      parser.on('-a', '--auto-correct', 'Auto-correct offenses.') do
        options[:auto_correct] = true
      end
      parser.on('-c', '--config=', "Specify configuration file. (default: #{@default_configuration_path} or .rubocop.yml)") do |file_path|
        options[:additional_config_file_path] = file_path
      end
      parser.on('--[no-]color', 'Force color output on or off.') do |value|
        options[:color] = value
      end
      parser.parse(@argv)
      options
    end
  end
end
