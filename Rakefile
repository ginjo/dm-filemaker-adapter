require 'bundler'
Bundler.require

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

desc "version"
task :version do
	require 'dm-filemaker-adapter/version'
	p DataMapper::FilemakerAdapter::VERSION
end