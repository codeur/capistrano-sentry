# frozen_string_literal: true

# This task will notify Sentry via their API[1][2] that you have deployed
# a new release. It uses the commit hash as the `version` and the git ref as
# the optional `ref` value.
#
# [1]: https://docs.sentry.io/api/releases/post-project-releases/
# [2]: https://docs.sentry.io/api/releases/post-release-deploys/

# For Rails app, this goes in config/deploy.rb

module Capistrano
  class SentryConfigurationError < StandardError
  end
end

namespace :sentry do
  desc 'Confirm configuration for notification to Sentry'
  task :validate_config do
    run_locally do
      info '[sentry:validate_config] Validating Sentry notification config'
      api_token = ENV['SENTRY_API_TOKEN'] || fetch(:sentry_api_token)
      if api_token.nil? || api_token.empty?
        msg = 'Missing SENTRY_API_TOKEN. Please set SENTRY_API_TOKEN environment' \
          ' variable or `set :sentry_api_token` in your `config/deploy.rb` file for your Rails application.'
        warn msg
        raise Capistrano::SentryConfigurationError, msg
      end
    end
  end

  desc 'Notice new deployment in Sentry'
  task :notice_deployment do
    run_locally do
      require 'uri'
      require 'net/https'
      require 'json'

      head_revision = fetch(:current_revision) || `git rev-parse HEAD`.strip
      prev_revision = fetch(:previous_revision) || `git rev-parse #{fetch(:current_revision)}^`.strip

      sentry_host = ENV['SENTRY_HOST'] || fetch(:sentry_host, 'https://sentry.io')
      organization_slug = fetch(:sentry_organization) || fetch(:application)
      project = fetch(:sentry_project) || fetch(:application)
      environment = fetch(:stage) || 'default'
      api_token = ENV['SENTRY_API_TOKEN'] || fetch(:sentry_api_token)
      repo_integration_enabled = fetch(:sentry_repo_integration, true)
      files_glob_pattern = fetch(:sentry_files_glob_pattern, '')
      files_prefix = fetch(:sentry_files_prefix, '')
      release_refs = fetch(:sentry_release_refs, [{
        repository:     fetch(:sentry_repo) || fetch(:repo_url).split(':').last.delete_suffix('.git'),
        commit:         head_revision,
        previousCommit: prev_revision
      }])
      release_version = fetch(:sentry_release_version) || head_revision
      deploy_name = fetch(:sentry_deploy_name) || "#{release_version}-#{fetch(:release_timestamp)}"

      uri = URI.parse(sentry_host)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      headers = {
        'Content-Type'  => 'application/json',
        'Authorization' => "Bearer #{api_token}"
      }

      # Notify release
      req = Net::HTTP::Post.new("/api/0/organizations/#{organization_slug}/releases/", headers)
      body = {
        version:  release_version,
        projects: project.split(' ').reject(&:empty?)
      }
      body[:refs] = release_refs if repo_integration_enabled
      req.body = JSON.generate(body)
      response_release = http.request(req)
      if response_release.is_a? Net::HTTPSuccess
        info "Notified Sentry of new release: #{release_version}"
      end

      # Upload files if configured
      unless files_glob_pattern.empty?
        if response_release.is_a? Net::HTTPSuccess
          info "Uploading files to sentry: #{files_glob_pattern} with prefix #{files_prefix}"
          Dir.glob(files_glob_pattern).each do |file|
            name = "#{files_prefix}#{File.basename(file)}"

            req = Net::HTTP::Post.new(
              "/api/0/organizations/#{organization_slug}/releases/#{release_version}/files/",
              headers
            )

            form_data = [['name', name], ['file', File.open(file)]]
            req.set_form form_data, 'multipart/form-data'

            response_file = http.request(req)
            if response_file.is_a? Net::HTTPSuccess
              info " - #{file} -> #{name}"
            else
              warn " - Cannot upload file. Response: #{response_file.code.inspect}: #{response_file.body}"
            end
          end
          # end Dir.glob(...).each do|file|
        else
          warn "Cannot upload sourcemaps to sentry for new release. \
            Response: #{response_release.code.inspect}: #{response_release.body}"
        end
      end

      # Notify deployment
      if response_release.is_a? Net::HTTPSuccess
        req = Net::HTTP::Post.new(
          "/api/0/organizations/#{organization_slug}/releases/#{release_version}/deploys/",
          headers
        )
        req.body = JSON.generate(
          environment: environment,
          name:        deploy_name
        )
        response_deploy = http.request(req)
        if response_deploy.is_a? Net::HTTPSuccess
          info "Notified Sentry of new deployment: #{deploy_name}"
        else
          warn "Cannot notify sentry for new deployment. \
            Response: #{response_deploy.code.inspect}: #{response_deploy.body}"
        end
      else
        warn "Cannot notify sentry for new release. \
          Response: #{response_release.code.inspect}: #{response_release.body}"
      end
    end
  end
end
