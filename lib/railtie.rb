require 'capistrano3-ubuntu-server-prepare'
require 'rails'
module EasyDeploy
  class Railtie < Rails::Railtie
    railtie_name :ubuntu_server_prepare

    rake_tasks do
      load "tasks/capstrano3-ubuntu-server-prepare.rake"
    end
  end
end
