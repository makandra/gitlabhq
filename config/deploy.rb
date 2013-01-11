require 'bundler/capistrano'

set :use_sudo, false
set :deploy_via, :remote_cache
set :copy_exclude, [ '.git' ]

set :repository, "git://github.com/makandra/gitlabhq.git"
set :scm, :git

set :user, "deploy-code-makandra"
set :deploy_to, '/opt/www/code.makandra.de'
set :rails_env, 'production'
set :branch, 'makandra'
server "dev.makandra.de", :app, :web, :cron, :db, :primary => true

set :default_environment, {
  'PATH' => "/home/deploy-code-makandra/.rvm/gems/ruby-1.9.3-p0/bin:/home/deploy-code-makandra/.rvm/gems/ruby-1.9.3-p0@global/bin:/home/deploy-code-makandra/.rvm/rubies/ruby-1.9.3-p0/bin:$PATH",
  'RUBY_VERSION' => 'ruby-1.9.3-p0',
  'GEM_HOME'     => '/home/deploy-code-makandra/.rvm/gems/ruby-1.9.3-p0',
  'GEM_PATH'     => '/home/deploy-code-makandra/.rvm/gems/ruby-1.9.3-p0:/home/deploy-code-makandra/.rvm/gems/ruby-1.9.3-p0@global'
}


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
    run "ln -nfs #{shared_path}/config/secret_token.rb #{release_path}/config/initializers/secret_token.rb" 
    run "ln -nfs #{shared_path}/config/gitlab.yml #{release_path}/config/gitlab.yml"
  end

end

namespace :god do
  def god_is_running
    !capture("#{god_command} status >/dev/null 2>/dev/null || echo 'not running'").start_with?('not running')
  end

  def god_command
    "cd #{current_path}; bundle exec god"
  end

  desc "Stop god"
  task :terminate_if_running do
    if god_is_running
      run "#{god_command} terminate"
    end
  end

  desc "Start god"
  task :start do
    config_file = "#{current_path}/config/god/resque.god"
    environment = { :RAILS_ENV => rails_env, :RAILS_ROOT => current_path }
    run "#{god_command} -c #{config_file}", :env => environment
  end
end

before "deploy:update", "god:terminate_if_running"
after "deploy:update", "god:start"

before "deploy:update_code", "db:dump"
before "deploy:setup", :db
after "deploy:update_code", "db:symlink" 
after "deploy:update_code", "deploy:additional_symlinks"
before "deploy:setup", 'deploy:setup_storage'
after "deploy:symlink", "db:warn_if_pending_migrations"
after "deploy:restart", "db:show_dump_usage"

load 'deploy/assets'
