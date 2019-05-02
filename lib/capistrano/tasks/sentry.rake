# This task will notify Sentry via their API[1] that you have deployed
# a new release. It uses the commit hash as the `version` and the git ref as
# the optional `ref` value.
#
# [1]: https://docs.getsentry.com/hosted/api/releases/post-project-releases

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
        msg = "Missing SENTRY_API_TOKEN. Please set SENTRY_API_TOKEN environment variable or `set :sentry_api_token` in your `config/deploy.rb` file for your Rails application."
        warn msg
        fail Capistrano::SentryConfigurationError, msg
      end
    end
  end

  desc 'Notice new deployment in Sentry'
  task :notice_deployment do
    run_locally do
      require 'uri'
      require 'net/https'
      require 'json'

      version = `git rev-parse HEAD`.strip

      sentry_host = ENV['SENTRY_HOST'] || fetch(:sentry_host, 'https://sentry.io')
      orga_slug = fetch(:sentry_organization) || fetch(:application)
      project = fetch(:sentry_project) || fetch(:application)
      environment = fetch(:stage) || 'default'
      api_token = ENV['SENTRY_API_TOKEN'] || fetch(:sentry_api_token)
      repo_name = fetch(:sentry_repo) || fetch(:repo_url).split(':').last.gsub(/\.git$/, '')

      uri = URI.parse(sentry_host)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      headers = {
        'Content-Type' => 'application/json',
        'Authorization' => 'Bearer ' + api_token.to_s
      }

      req = Net::HTTP::Post.new("/api/0/organizations/#{orga_slug}/releases/", headers)
      req.body = JSON.generate(
        version: version,
        refs: [{
          repository: repo_name,
          commit: fetch(:current_revision) || `git rev-parse HEAD`.strip
        }],
        projects: [project]
      )
      response = http.request(req)
      if response.is_a? Net::HTTPSuccess
        info 'Uploaded release infos to Sentry'
        req = Net::HTTP::Post.new("/api/0/organizations/#{orga_slug}/releases/#{version}/deploys/", headers)
        req.body = JSON.generate(
          environment: environment,
          name: "#{version}-#{fetch(:release_timestamp)}"
        )
        response = http.request(req)
        if response.is_a? Net::HTTPSuccess
          info 'Uploaded deployment infos to Sentry'
        else
          warn "Cannot notify sentry for new deployment. Response: #{response.code.inspect}: #{response.body}"
        end
      else
        warn "Cannot notify sentry for new release. Response: #{response.code.inspect}: #{response.body}"
      end
    end
  end
end

# If you want deployments to be published in every Rails environment, put this
# in config/deploy.rb, otherwise put it your environment-specific deploy file
# i.e. config/deploy/production.rb
# after 'deploy:published', 'sentry:notice_deployment'
