lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'capistrano/sentry/version'

Gem::Specification.new do |spec|
  spec.name          = 'capistrano-sentry'
  spec.version       = Capistrano::Sentry::VERSION
  spec.authors       = ['Brice Texier']
  spec.email         = ['brice@codeur.com']
  spec.description   = 'Sentry release/deployment integration'
  spec.summary       = 'Sentry release/deployment integration'
  spec.homepage      = 'https://github.com/codeur/capistrano-sentry'
  spec.license       = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.test_files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").select { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'capistrano', '~> 3.1'

  spec.add_development_dependency 'bundler', '~> 1.17'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 10.0'
end
