require "highline/import"
require 'erb'
require 'pathname'
namespace :ubuntu_server_prepare do
	desc "rake ubuntu_server_prepare:copy_config"
	task :copy_config do
		tasks_dir = Pathname.new('lib/capistrano/tasks')
		config_dir = Pathname.new('config')
		production_dir = config_dir.join('production')
		deploy_rb = File.expand_path("../../../config/production", __FILE__)
		FileUtils.cp_r(deploy_rb, config_dir)
	end
end
