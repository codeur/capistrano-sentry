# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'capistrano/all'
Rake.application.options.trace = false # re-enabled by capistrano/all
require 'minitest/autorun'
require 'stringio'
require 'net/http'
require 'json'

include Capistrano::DSL # rubocop:disable Style/MixinUsage

require 'capistrano/sentry'

module Capistrano
  # Runs Capistrano tasks against a fresh configuration, with SSHKit output captured
  # and Sentry's HTTP API replaced by a recorder.
  class TestCase < Minitest::Test
    class FakeHTTP
      attr_reader :requests

      def initialize
        @requests = []
      end

      def use_ssl=(_value); end

      def request(req)
        @requests << req
        Net::HTTPCreated.new('1.1', '201', 'Created').tap do |response|
          response.instance_variable_set(:@body, '{}')
          response.instance_variable_set(:@read, true)
        end
      end
    end

    def setup
      Capistrano::Configuration.reset!
      @log = StringIO.new
      SSHKit.config.output = SSHKit::Formatter::Pretty.new(@log)
      SSHKit.config.output_verbosity = :debug
      @http = FakeHTTP.new
      set :application, 'my-app'
      set :repo_url, 'git@github.com:my-org/my-app.git'
      set :sentry_api_token, 'secret'
      set :current_revision, 'abc123'
      set :previous_revision, 'def456'
      set :release_timestamp, '20260910120000'
    end

    def run_task(name)
      task = Rake::Task["sentry:#{name}"]
      task.reenable
      Net::HTTP.stub(:new, @http) { task.invoke }
    end

    def log
      @log.string
    end
  end
end
