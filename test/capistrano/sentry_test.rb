# frozen_string_literal: true

require 'test_helper'

module Capistrano
  class SentryTest < TestCase
    def test_production_creates_a_release_and_a_deploy
      set :stage, :production
      run_task :notice_deployment

      assert_equal 2, @http.requests.size
      release, deploy = @http.requests
      assert_equal '/api/0/organizations/my-app/releases/', release.path
      assert_equal 'Bearer secret', release['Authorization']
      body = JSON.parse(release.body)
      assert_equal 'abc123', body['version']
      assert_equal ['my-app'], body['projects']
      assert_equal 'my-org/my-app', body['refs'].first['repository']
      assert_equal '/api/0/organizations/my-app/releases/abc123/deploys/', deploy.path
      assert_equal({ 'environment' => 'production', 'name' => 'abc123-20260910120000' }, JSON.parse(deploy.body))
      assert_includes log, 'Notified Sentry of new deployment'
    end

    def test_other_stages_do_not_notify_sentry
      set :stage, :staging
      run_task :notice_deployment

      assert_empty @http.requests
      assert_includes log, 'Skipped: stage :staging is not listed in :sentry_stages'
    end

    def test_sentry_stages_can_enable_other_stages
      set :stage, :staging
      set :sentry_stages, %w[staging production]
      run_task :notice_deployment

      assert_equal 2, @http.requests.size
      assert_equal 'staging', JSON.parse(@http.requests.last.body)['environment']
    end

    def test_validate_config_requires_a_token_on_enabled_stages
      set :stage, :production
      set :sentry_api_token, nil

      assert_raises(Capistrano::SentryConfigurationError) { run_task :validate_config }
    end

    def test_validate_config_is_skipped_on_other_stages
      set :stage, :staging
      set :sentry_api_token, nil

      run_task :validate_config
      assert_includes log, 'Skipped: stage :staging is not listed in :sentry_stages'
    end
  end
end
