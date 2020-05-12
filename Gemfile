# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

gem 'pry'
gem 'rake', '~> 12.0'
gem 'rspec', '~> 3.7'
# Workaround for cc-test-reporter with SimpleCov 0.18.
# Stop upgrading SimpleCov until the following issue will be resolved.
# https://github.com/codeclimate/test-reporter/issues/418
gem 'rubocop', github: 'rubocop-hq/rubocop'
gem 'rubocop-performance', '~> 1.5.0'
gem 'rubocop-rspec', '~> 1.33.0'
gem 'simplecov', '~> 0.10', '< 0.18'
gem 'test-queue'
gem 'yard', '~> 0.9'

local_gemfile = File.expand_path('Gemfile.local', __dir__)
eval_gemfile local_gemfile if File.exist?(local_gemfile)
