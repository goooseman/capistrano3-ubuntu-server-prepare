namespace :ubuntu_server_prepare do

    desc 'Configure ubuntu server'
    task :default do
        invoke_scrpipts = []
        if yesno 'Do you want to increase ssh security?'
            invoke_scrpipts << 'ubuntu_server_prepare:ssh_increase'
        end
        if yesno 'Do you want to make swapfile?'
            set :swapfile_size, ask("size of swapfile?", '512k')
            fetch :swapfile_size
            invoke_scrpipts << 'ubuntu_server_prepare:make_swap'
        end
        invoke_scrpipts << 'ubuntu_server_prepare:update_apt'
        if yesno 'Do you want to apt-get upgrade?'
            invoke_scrpipts << 'ubuntu_server_prepare:upgrade_apt'
        end
        if yesno 'Do you want to install NGINX?'
            if yesno 'Do you want to install pagespeed module for nginx?'
                set :pagespeed_install, true
            else
                set :pagespeed_install, false
            end
            invoke_scrpipts << 'ubuntu_server_prepare:nginx_install'
        end

        if yesno 'Do you want to install postgreSQL?'
            set :postgre_username, ask("username for postgreSQL", 'deployer')
            set :postgre_password, ask("password for postgreSQL", '123456')
            fetch :postgre_username
            fetch :postgre_password
            invoke_scrpipts << 'ubuntu_server_prepare:postgre_install'
        end
        if yesno 'Do you want to install Redis?'
            invoke_scrpipts << 'ubuntu_server_prepare:redis_install'
            invoke_scrpipts << 'ubuntu_server_prepare:redis_conf'
        end
        if yesno 'Do you want to install RVM with Rails and Bundler?'
            invoke_scrpipts << 'ubuntu_server_prepare:rvm_install'
        end

        if yesno 'Do you want to copy private key (for accessing git repo) from local machine to remote?'
            set :key_localtion, ask("private key location", '~/.ssh/id_rsa')
            fetch :key_localtion
            invoke_scrpipts << 'ubuntu_server_prepare:push_ssh_keys'
        end

        if yesno 'Do you want to install imagemagick?'
            invoke_scrpipts << 'ubuntu_server_prepare:imagemagick_install'
        end

        if yesno 'Do you want tp install some other packages?', false
            set :additional_packages, ask("additional packages to install separated by space", 'apticron logcheck fail2ban') if !fetch :additional_packages
            fetch :additional_packages
            invoke_scrpipts << 'ubuntu_server_prepare:additional_install'
        end
        # just to get password before start
        sudo_command
        invoke_scrpipts.each do |script|
            invoke script
        end
    end


    desc 'Ask for sudo password'
    task :ask_password do
        on roles(:all) do
            set :password, ask("your server sudo password", nil)
            password = fetch(:password)
            puts 'Checking password'
            if 'true' == capture("echo #{password} | sudo -kS echo true").strip
                set :sudo_password, password
                set :sudo_command, "echo #{password} | sudo -kS "
                puts "Password correct"
            else
                raise "Password incorrect"
            end
        end
    end


    desc "Increase ssh security"
    task :ssh_increase do
        on roles(:all) do
            user = capture("echo $USER")
            execute sudo_command + "sh -c \"echo 'PermitRootLogin no'  >> /etc/ssh/sshd_config\""
            execute sudo_command + "sh -c \"echo 'UseDNS no'  >> /etc/ssh/sshd_config\""
            execute sudo_command + "sh -c \"echo 'AllowUsers #{user}'  >> /etc/ssh/sshd_config\""
            execute sudo_command + 'reload ssh'
        end
    end


    desc 'Install imagemagick'
    task :imagemagick_install do
        on roles(:all) do
            execute sudo_command + "apt-get -y install imagemagick"
        end
    end

    desc 'Make Swap'
    task :make_swap do
        on roles(:all) do
            set :swapfile_size, ask("size of swapfile?", '512k') if !fetch(:swapfile_size)
            execute sudo_command + "dd if=/dev/zero of=/swapfile bs=1024 count=#{fetch :swapfile_size}"
            execute sudo_command + 'mkswap /swapfile'
            execute sudo_command + 'swapon /swapfile'
            execute sudo_command + "sh -c \"echo '/swapfile       none    swap    sw      0       0 '  >> /etc/fstab\""
            execute sudo_command + "sh -c \"echo 0 >> /proc/sys/vm/swappiness\""
            execute sudo_command + 'chown root:root /swapfile'
            execute sudo_command + 'chmod 0600 /swapfile'
        end
    end

    desc 'Update'
    task :update_apt do
        on roles(:all) do
            execute sudo_command + 'apt-get update'
        end
    end

    desc 'Update and upgrade'
    task :upgrade_apt do
        on roles(:all) do
            execute sudo_command + 'apt-get  --yes --force-yes dist-upgrade'
        end
    end

    desc 'Install nginx'
    task :nginx_install do
        on roles(:all) do
            if fetch(:pagespeed_install).class == NilClass
                if yesno 'Do you want to install pagespeed module for nginx?'
                    set :pagespeed_install, true
                else
                    set :pagespeed_install, false
                end
            end


            execute sudo_command + 'apt-get  --yes --force-yes install build-essential zlib1g-dev libpcre3 libpcre3-dev unzip checkinstall libssl-dev'
            execute 'mkdir -p ~/sources/nginx'

            if fetch :pagespeed_install
                nps_version = '1.9.32.2'
                within '~/sources/nginx' do
                    execute  :wget, "https://github.com/pagespeed/ngx_pagespeed/archive/release-#{nps_version}-beta.zip"
                    execute :unzip, "release-#{nps_version}-beta.zip"
                end
                within "~/sources/nginx/ngx_pagespeed-release-#{nps_version}-beta" do
                    execute :wget, "https://dl.google.com/dl/page-speed/psol/#{nps_version}.tar.gz"
                    execute :tar, "-xzvf #{nps_version}.tar.gz"
                end
            end

            nginx_version = '1.8.0'
            within '~/sources/nginx' do
                execute :wget, "http://nginx.org/download/nginx-#{nginx_version}.tar.gz"
                execute :tar, "-xvzf nginx-#{nginx_version}.tar.gz"
            end
            within "~/sources/nginx/nginx-#{nginx_version}" do
                if fetch :pagespeed_install
                    execute "cd ~/sources/nginx/nginx-#{nginx_version} && ./configure --add-module=$HOME/sources/nginx/ngx_pagespeed-release-#{nps_version}-beta --with-http_ssl_module"
                else
                    execute "cd ~/sources/nginx/nginx-#{nginx_version} && ./configure --with-http_ssl_module"
                end
                execute :make
            end
            execute "cd ~/sources/nginx/nginx-#{nginx_version} && " + sudo_command + "checkinstall -y"

            execute sudo_command + "useradd -s /sbin/nologin -r nginx"
            execute sudo_command + "groupadd web"
            execute sudo_command + "usermod -a -G web nginx"
            user = capture("echo $USER")
            execute sudo_command + "usermod -a -G web #{user}"
            execute sudo_command + "mkdir -p /var/www/run"
            execute sudo_command + "mkdir -p /var/www/log"
            execute sudo_command + "chgrp -R web /var/www"
            execute sudo_command + "chmod -R 775 /var/www"
            execute sudo_command + "chown -R #{user} /var/www"
            invoke 'ubuntu_server_prepare:nginx_conf'
        end
    end

    desc 'Send nginx config files'
    task :nginx_conf do
        on roles(:all) do
            if fetch(:pagespeed_install).class == NilClass
                if yesno 'Do you want to install pagespeed module for nginx?'
                    set :pagespeed_install, true
                else
                    set :pagespeed_install, false
                end
            end

            execute "mkdir -p ~/sources/nginx/conf"
            user = capture("echo $USER")
            if fetch :pagespeed_install
                upload! 'config/production/nginx/nginx_with_pagespeed.conf', "/home/#{user}/sources/nginx/conf/nginx.conf"
            else
                upload! 'config/production/nginx/nginx.conf', "/home/#{user}/sources/nginx/conf/nginx.conf"

            end
            upload! 'config/production/nginx/upstart.conf', "/home/#{user}/sources/nginx/conf/"
            execute sudo_command + "cp -f ~/sources/nginx/conf/upstart.conf /etc/init/nginx.conf"
            execute sudo_command + "cp -f ~/sources/nginx/conf/nginx.conf /usr/local/nginx/conf/nginx.conf"
            nginx_status = capture(sudo_command + "status nginx")
            if nginx_status == 'nginx stop/waiting'
                execute sudo_command + "start nginx"
            else
                execute sudo_command + 'restart nginx'
            end
        end
    end

    desc 'Install PostgreSql'
    task :postgre_install do
        on roles(:all) do
            set :postgre_username, ask("username for postgreSQL", 'deployer') if !fetch(:postgre_username)
            set :postgre_password, ask("password for postgreSQL", '123456') if !fetch(:postgre_password)

            execute sudo_command + "apt-get install -y postgresql-9.3 postgresql-server-dev-9.3 postgresql-contrib"
            execute sudo_command + "-u postgres psql -c \"create user #{fetch :postgre_username} with password '#{fetch :postgre_password}';\""
            execute sudo_command + "-u postgres psql -c \"alter role #{fetch :postgre_username} superuser createrole createdb replication;\""
        end
    end

    desc 'Install Redis'
    task :redis_install do
        on roles(:all) do
            execute "mkdir -p ~/sources/redis"
            execute sudo_command + "apt-get install -y tcl8.5"
            within "~/sources/redis" do
                execute :wget, "http://download.redis.io/redis-stable.tar.gz"
                execute :tar, "xvzf redis-stable.tar.gz"
            end
            within "~/sources/redis/redis-stable" do
                execute :make
            end
            execute sudo_command + "cp -f ~/sources/redis/redis-stable/src/redis-server /usr/local/bin/"
            execute sudo_command + "cp -f ~/sources/redis/redis-stable/src/redis-cli /usr/local/bin/"
            execute sudo_command + "mkdir -p /etc/redis/"
            execute sudo_command + "cp ~/sources/redis/redis-stable/redis.conf /etc/redis/"
        end
    end

    desc 'Configure Redis'
    task :redis_conf do
        on roles(:all) do
            user = capture("echo $USER")
            execute sudo_command + "mkdir -p /var/www/other"
            execute sudo_command + "mkdir -p /var/www/log"
            execute sudo_command + "chgrp -R web /var/www"
            execute sudo_command + "chmod -R 775 /var/www"
            execute sudo_command + "chown -R #{user} /var/www"
            execute "mkdir -p ~/sources/redis/conf"

            upload! 'config/production/redis/redis.conf', "/home/#{user}/sources/redis/conf/"
            upload! 'config/production/redis/upstart.conf', "/home/#{user}/sources/redis/conf/"
            execute sudo_command + "cp -f ~/sources/redis/conf/upstart.conf /etc/init/redis-server.conf"
            execute sudo_command + "cp -f ~/sources/redis/conf/redis.conf /etc/redis/"

            redis_status = capture(sudo_command + "status redis-server")
            if redis_status == 'redis-server stop/waiting'
                execute sudo_command + "start redis-server"
            else
                execute sudo_command + 'restart redis-server'
            end
        end
    end

    desc 'Install RVM with rails'
    task :rvm_install do
        on roles(:all) do
            execute sudo_command + 'apt-get -y install git curl python-software-properties software-properties-common'
            execute sudo_command + 'add-apt-repository -y ppa:chris-lea/node.js'
            execute sudo_command + 'apt-get update'
            execute sudo_command + 'apt-get -y install nodejs gawk g++ gcc make libreadline6-dev zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 autoconf libgdbm-dev libncurses5-dev automake libtool bison pkg-config libffi-dev libgmp-dev'
            execute "gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3"
            execute "\\curl -sSL https://get.rvm.io | bash -s stable --rails --gems=bundler --autolibs=read-fail"
        end
    end



    desc 'Push ssh key to server'
    task :push_ssh_keys do
        on roles(:all) do
            files =  Dir.glob(Dir.home() + '/.ssh/*').select { |f| f !~ /\.pub|known|config/ }.map {|f| f.gsub!(Dir.home(), '~')}
            set :key_localtion, ask("private key location (for example: #{files.join(', ')})", '~/.ssh/id_rsa') if !fetch :key_localtion
            home = Dir.home()
            key_location = fetch(:key_localtion).gsub('~', home)
            until File.exists? key_location
                set :key_localtion, ask("private key location (for example: #{files.join(', ')})", '~/.ssh/id_rsa')
                key_location = fetch(:key_localtion).gsub('~', home)
            end
            execute "mkdir -p ~/.ssh"
            user = capture("echo $USER")
            upload! key_location, "/home/#{user}/.ssh/git_key"
            upload! key_location + '.pub', "/home/#{user}/.ssh/git_key.pub"
            execute "echo 'IdentityFile ~/.ssh/git_key' >> ~/.ssh/config"
            execute "chmod -f 600 ~/.ssh/*"
        end
    end

    desc 'Install additional packages'
    task :additional_install do
        on roles(:all) do
            set :additional_packages, ask("additional packages to install separated by space", 'apticron logcheck fail2ban') if !fetch :additional_packages
            execute sudo_command + "apt-get -y install #{fetch :additional_packages}"
        end
    end



    def sudo_command
        sudo_command = fetch(:sudo_command)
        if !sudo_command
            invoke "ubuntu_server_prepare:ask_password"
            sudo_command = fetch(:sudo_command)
        end
        return sudo_command
    end



    def yesno(prompt = 'Continue?', default = true)
        a = ''
        s = default ? '[Y/n]' : '[y/N]'
        d = default ? 'y' : 'n'
        until a =~ /\Ay|n\z/
            set :answer, ask("#{prompt} #{s}", d)

            a = fetch(:answer)
        end
        a.downcase == 'y'
    end

end
task :ubuntu_server_prepare => "ubuntu_server_prepare:default"
