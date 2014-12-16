# capistrano3-ubuntu-server-prepare

This Capistrano (v3) task helps you to configure your blank ubuntu server before your first  deploy.

It can:
* Make SSH more secure ('PermitRootLogin no', 'UseDNS no', 'AllowUsers username' SSH settings)
* Make swap (It asks for the size, default is 512k)
* Update and upgrade your server
* Install NGINX from source with or without Pagespeed module
* Install PostgreSQL and create user (It asks for db username and password)
* Install Redis
* Install RVM with latest Ruby, Rails and Bundler
* Copy your private ssh key (so you can login to your private git repo like BitBucket from the server)
* Install imagemagick (Needed by Paperclip)
* Install any additional Ubuntu packages (It asks which exactly)

You can run configuration wizard, which will ask you what to do and for some additional settings, and will do all the work, so you can go and drink some coffee. Or you can look at the source and run any of the tasks on its own.

Note! It requires nginx, redis and unicorn config files in 'config/production' folder of your project. You can get them by running ``` rake ubuntu_server_prepare:copy_config ```

**Attention!** My nginx and unicorn configuration files are made for your application running from /var/www/application/current. So add ``` set :application, 'application' ``` to your ``` config/deploy.rb ``` before first deploy or edit the configs.

For a complete usage instructions see [usage](#usage)

## Installation

Add this line to your application's Gemfile:

```ruby
group :development do
	gem 'capistrano'
	gem 'capistrano3-ubuntu-server-prepare'
end
```

And then execute:

    $ bundle

Run
``` ruby
 rake ubuntu_server_prepare:copy_config
```
 and edit config files in ``` config/production ```

 Add
``` ruby
require 'capistrano3/ubuntu-server-prepare'
```
to your ``` Capfile ``` (If non exists run ``` cap install ```).


## Usage

Just imagine: you have some blank Ubuntu server. All you need to do manually is creating not root user, ``` visudo```ing it and copying ssh keys, so you can login from your local machine without password.

  So login as root to your server and do the following:

* ``` adduser deployer ``` (name can be anything)
* ``` echo "deployer ALL=(ALL) ALL" >> /etc/sudoers ``` (change deployer to your name)

On your local machine:

* ``` ssh-copy-id deployer@111.111.111.111 ``` (change deployer to your username and 111.111.111.111 to your server ip)
* Add
``` ruby
group :development do
	gem 'capistrano'
	gem 'capistrano3-ubuntu-server-prepare'
end
```
to your project ``` Gemfile ```
* Run ``` bundle install ``` from your project folder
* Run ``` rake ubuntu_server_prepare:copy_config ```
* Edit ``` config/production ``` config files, if you want
* Add ``` require 'capistrano3/ubuntu-server-prepare' ``` to your ``` Capfile ``` (``` cap install ``` if there isn't any)
* Be sure that line ``` require 'capistrano/rvm' ``` in your ``` Capfile ``` is commented.You can uncomment it after the process finishes.
* Edit ``` config/deploy/production.rb ``` so the only uncommented line will looks like
``` ruby
server '111.111.111.111', user: 'deployer', roles: %w{web app db}
```
* Run ``` cap production ubuntu_server_prepare ``` to run configuration wizard
* Answer all the questions and go to drink some coffee

**Attention!** My nginx and unicorn configuration files are made for your application running from /var/www/application/current. So add ``` set :application, 'application' ``` to your ``` config/deploy.rb ``` before first deploy or edit the configs.

## What to do next?

So your server is configured, what to do next? How to deploy your app? OK, it is really easy:

* Be sure that settings for production are right in ``` db/database.yml ```
* Open your ``` Gemfile ``` and be sure you have these gems:
``` ruby
group :development do
	gem 'capistrano'
	gem 'capistrano-rails'
	gem 'capistrano-bundler'
	gem 'capistrano3-unicorn'
	gem 'capistrano-rvm'
	gem 'capistrano3-ubuntu-server-prepare'
	gem 'capistrano3-git-push'
end
group :production do
	gem 'unicorn'
end
```
* Open your ``` Capfile ``` and be sure you have these lines:
``` ruby
# Load DSL and set up stages
require 'capistrano/setup'

# Include default deployment tasks
require 'capistrano/deploy'
require 'capistrano3/ubuntu-server-prepare'
require 'capistrano3/unicorn'
require 'capistrano3/git-push'
require 'capistrano/rvm'
require 'capistrano/bundler'
require 'capistrano/rails'
```
* Open ``` config/deploy.rb ``` and paste your git server address in ``` set :repo_url ``` (You can use [BitBucket](https://bitbucket.org) for a good free private repository)
* Add
``` ruby
set :unicorn_config_path, "#{current_path}/config/production/unicorn/unicorn.rb"
```
* Add
``` ruby
set :linked_dirs, fetch(:linked_dirs, []).push('bin', 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system')
```

* Add
``` ruby
  task :setup do
    before "deploy:migrate", :create_db
    invoke :deploy
  end

  task :create_db do
    on roles(:all) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "db:create"
        end
      end
    end
  end
```
right after ``` namespace :deploy do ``` line
* Add
``` ruby
before :deploy, 'git:push'
before 'deploy:setup', 'git:push'

after 'deploy:publishing', 'deploy:restart'
namespace :deploy do
  task :restart do
    invoke 'unicorn:legacy_restart'
  end
end
```
to the end of the file
* Run ``` cap production deploy:setup ``` for the first time (it will run rake db:create), next times use ``` cap production deploy ```

## Folder Structure
```
/usr/local/nginx/conf/nginx.conf # NGINX conf
/etc/redis/ # Redis conf
/var/www/
-- log/ # Nginx and Redis log files here
-- run/ # Nginx and Redis pid files here
-- application/
---- current/ # Your Rails app
------ log/ # Rails and Unicorn log file here
------ tmp/pids/ # Unicorn pid files here
------ tmp/sockets/ # Unicorn socket files here
```