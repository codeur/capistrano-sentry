# frozen_string_literal: true

require 'test_helper'
require 'capistrano/sentry/version'

module Capistrano
  class SentryTest < Minitest::Test
    def test_that_it_has_a_version_number
      assert !::Capistrano::Sentry::VERSION.nil?
    end
  end
end
