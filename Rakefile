# frozen_string_literal: true

namespace :test do
  desc 'Run all tests'
  task :run do
    exec 'bundle exec rspec'
  end
end

desc 'Start the server'
task :server do
  exec 'bundle exec puma -C config/puma.rb'
end

task default: 'test:run'
