require 'bundler/capistrano'

set :rvm_ruby_string, 'ruby-2.1.2'

require 'rvm/capistrano'

require 'sidekiq/capistrano'

set :use_sudo, false
set :deploy_via, :remote_cache
set :copy_exclude, [ '.git' ]

set :repository, "git://github.com/makandra/gitlabhq.git"
set :scm, :git

set :user, "git"
set :deploy_to, '/home/git/code.makandra.de'
set :rails_env, 'production'
set :branch, 'makandra'
server "dev.makandra.de", :app, :web, :cron, :db, :cache, :primary => true

ssh_options[:keys_only] = true

namespace :passenger do
  desc "Restart Application"
  task :restart do
    run "touch #{current_path}/tmp/restart.txt"
  end
end

namespace :db do
  desc "Create database yaml in shared path" 
  task :default do
    run "mkdir -p #{shared_path}/config" 
    put File.read("config/database.yml"), "#{shared_path}/config/database.yml" 
  end

  desc "Make symlink for database yaml" 
  task :symlink do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml" 
  end

  desc "Warn about pending migrations"
  task :warn_if_pending_migrations, :roles => :db, :only => { :primary => true } do
    rails_env = fetch(:rails_env, 'production')
    run "cd #{release_path}; bundle exec rake db:warn_if_pending_migrations RAILS_ENV=#{rails_env}"
  end

  desc "Do a dump of the DB on the remote machine using dumple"
  task :dump do
    rails_env = fetch(:rails_env, 'production')
    run "cd #{current_path}; dumple #{rails_env}"
  end

  desc "Show usage of ~/dumps/ on remote host"
  task :show_dump_usage do
    run "dumple -i"
  end
  
end

namespace :deploy do

  desc "Create storage dir in shared path"
  task :setup_storage do
    run "mkdir -p #{shared_path}/storage"
  end
  
  task :restart do
    passenger.restart
  end

  task :start do
  end

  task :stop do
  end

  task :additional_symlinks do
    run "ln -nfs #{shared_path}/storage #{release_path}/storage"
    run "ln -nfs #{shared_path}/uploads #{release_path}/public/uploads"
    run "ln -nfs #{shared_path}/.secret #{release_path}/.secret" 
    run "ln -nfs #{shared_path}/config/gitlab.yml #{release_path}/config/gitlab.yml"
  end

end

namespace :cache do

  task :clear, :roles => :cache do
    rails_env = fetch(:rails_env, 'production')
    run "cd #{release_path}; bundle exec rake cache:clear RAILS_ENV=#{rails_env}"
  end

end

before "deploy:update_code", "db:dump"
before "deploy:setup", :db
after "deploy:update_code", "db:symlink" 
after "deploy:update_code", "deploy:additional_symlinks"
before "deploy:setup", 'deploy:setup_storage'
after "deploy:create_symlink", "db:warn_if_pending_migrations"
after "deploy:create_symlink", "cache:clear"
after "deploy:restart", "db:show_dump_usage"

load 'deploy/assets'

