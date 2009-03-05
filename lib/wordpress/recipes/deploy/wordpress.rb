_cset(:database_name)     { abort "Please specify the name of your Wordpress database, set :database_name, 'foo'" }
_cset(:database_username) { abort "Please specify the username for your Wordpress database, set :database_username, 'foo'" }
_cset(:database_password) { Capistrano::CLI.password_prompt("Please enter the database password for #{database_username} on #{database_name}: ") }

# QUESTION is there a better way than whacking what came before?
set :shared_children, %w(backups uploads)

def wordpress_config
  require 'digest/sha1'
  Wordpress.config(:db_name         => database_name,
                   :db_user         => database_username,
                   :db_password     => database_password,
                   :auth_key        => Digest::SHA1.hexdigest(rand.to_s),
                   :secure_auth_key => Digest::SHA1.hexdigest(rand.to_s),
                   :logged_in_key   => Digest::SHA1.hexdigest(rand.to_s),
                   :nonce_key       => Digest::SHA1.hexdigest(rand.to_s),
                   :abspath         => '/../current/public/')
end

def wordpress_restore_script
  "#!/bin/sh\ngzcat $1 | mysql -u #{database_username} -p #{database_name}"
end

# QUESTION is there a better way than overwriting these tasks?
namespace :deploy do
  task(:start)   {}
  task(:restart) {}
  task(:stop)    {}
end

namespace :wordpress do
  task :setup do
    put wordpress_config, "#{shared_path}/wp-config.php", :mode => 0600
    put wordpress_restore_script, "#{shared_path}/backups/restore", :mode => 0755
  end

  task :finalize_update do
    run <<-CMD
      rm -rf #{latest_release}/public/wp-config.php #{latest_release}/public/wp-content/uploads &&
      ln -s #{shared_path}/wp-config.php #{latest_release}/public/wp-config.php &&
      ln -s #{shared_path}/uploads #{latest_release}/public/wp-content/uploads
    CMD
  end

  desc "Use this instead of `cap deploy` when you're deploying an upgraded version of Wordpress."
  task :upgrade do
    run "mysqldump -u #{database_username} -p#{database_password} --compress --opt --lock-tables=false --skip-add-locks --skip-extended-insert #{database_name} | gzip > #{shared_path}/backups/#{release_name}.sql.gz"
    run "mysql -u #{database_username} -p#{database_password} -e 'update wp_options set option_value=\"a:0:{}\" where option_name=\"active_plugins\"' #{database_name}"
    deploy.default
    puts 'You should now visit wp-admin/upgrade.php and manually reactivate your plugins.'
  end
end

after 'deploy:setup', 'wordpress:setup'
after 'deploy:finalize_update', 'wordpress:finalize_update'
