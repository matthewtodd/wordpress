# =========================================================================
# This file started as a direct copy of capistrano/recipes/deploy.
# Thanks so much for Capistrano, Jamis!
# =========================================================================
require 'yaml'
require 'capistrano/recipes/deploy/scm'
require 'capistrano/recipes/deploy/strategy'

Capistrano::Configuration.instance(:must_exist).load do
  def _cset(name, *args, &block) #:nodoc:
    unless exists?(name)
      set(name, *args, &block)
    end
  end

  # =========================================================================
  # These variables MUST be set in the client capfiles. If they are not set,
  # the deploy will fail with an error.
  # =========================================================================

  _cset(:application)       { abort "Please specify the name of your application, set :application, 'foo'" }
  _cset(:repository)        { abort "Please specify the repository that houses your application's code, set :repository, 'foo'" }
  _cset(:database_name)     { abort "Please specify the name of your Wordpress database, set :database_name, 'foo'" }
  _cset(:database_username) { abort "Please specify the username for your Wordpress database, set :database_username, 'foo'" }

  # =========================================================================
  # These variables may be set in the client capfile if their default values
  # are not sufficient.
  # =========================================================================

  _cset :scm, :subversion
  _cset :deploy_via, :checkout

  _cset(:deploy_to) { "/u/apps/#{application}" }
  _cset(:revision)  { source.head }

  # =========================================================================
  # These variables should NOT be changed unless you are very confident in
  # what you are doing. Make sure you understand all the implications of your
  # changes if you do decide to muck with these!
  # =========================================================================

  _cset(:source)            { Capistrano::Deploy::SCM.new(scm, self) }
  _cset(:real_revision)     { source.local.query_revision(revision) { |cmd| with_env("LC_ALL", "C") { `#{cmd}` } } }

  _cset(:strategy)          { Capistrano::Deploy::Strategy.new(deploy_via, self) }

  _cset(:release_name)      { set :deploy_timestamped, true; Time.now.utc.strftime("%Y%m%d%H%M%S") }

  _cset :version_dir,       "releases"
  _cset :shared_dir,        "shared"
  _cset :current_dir,       "current"

  _cset(:releases_path)     { File.join(deploy_to, version_dir) }
  _cset(:shared_path)       { File.join(deploy_to, shared_dir) }
  _cset(:current_path)      { File.join(deploy_to, current_dir) }
  _cset(:release_path)      { File.join(releases_path, release_name) }

  _cset(:releases)          { capture("ls -x #{releases_path}").split.sort }
  _cset(:current_release)   { File.join(releases_path, releases.last) }
  _cset(:previous_release)  { File.join(releases_path, releases[-2]) }

  _cset(:current_revision)  { capture("cat #{current_path}/REVISION").chomp }
  _cset(:latest_revision)   { capture("cat #{current_release}/REVISION").chomp }
  _cset(:previous_revision) { capture("cat #{previous_release}/REVISION").chomp }

  _cset(:run_method)        { fetch(:use_sudo, true) ? :sudo : :run }

  _cset(:database_password) { Capistrano::CLI.password_prompt("Please enter the database password for #{database_username} on #{database_name}: ") }

  # some tasks, like symlink, need to always point at the latest release, but
  # they can also (occassionally) be called standalone. In the standalone case,
  # the timestamped release_path will be inaccurate, since the directory won't
  # actually exist. This variable lets tasks like symlink work either in the
  # standalone case, or during deployment.
  _cset(:latest_release) { exists?(:deploy_timestamped) ? release_path : current_release }

  # =========================================================================
  # These are helper methods that will be available to your recipes.
  # =========================================================================

  # Auxiliary helper method for the `deploy:check' task. Lets you set up your
  # own dependencies.
  def depend(location, type, *args) #:nodoc:
    deps = fetch(:dependencies, {})
    deps[location] ||= {}
    deps[location][type] ||= []
    deps[location][type] << args
    set :dependencies, deps
  end

  # Temporarily sets an environment variable, yields to a block, and restores
  # the value when it is done.
  def with_env(name, value) #:nodoc:
    saved, ENV[name] = ENV[name], value
    yield
  ensure
    ENV[name] = saved
  end

  # =========================================================================
  # These are the tasks that are available to help with deploying web apps,
  # and specifically, Wordpress. You can have cap give you a summary
  # of them with `cap -T'.
  # =========================================================================

  namespace :deploy do
    desc <<-DESC
      Copies your project and updates the symlink. It does this in a \
      transaction, so that if either `update_code' or `symlink' fail, all \
      changes made to the remote servers will be rolled back, leaving your \
      system in the same state it was in before `update' was invoked.
    DESC
    task :default do
      transaction do
        update_code
        symlink
      end
    end

    namespace :setup do
      desc <<-DESC
        Prepares one or more servers for deployment. Before you can use any \
        of the Capistrano deployment tasks with your project, you will need to \
        make sure all of your servers have been prepared with `cap deploy:setup'. When \
        you add a new server to your cluster, you can easily run the setup task \
        on just that server by specifying the HOSTS environment variable:

          $ cap HOSTS=new.server.com deploy:setup

        It is safe to run this task on servers that have already been set up; it \
        will not destroy any deployed revisions or data.
      DESC
      task :default, :except => { :no_release => true } do
        directories
        restore
        config
      end

      desc <<-DESC
        [internal] Creates deployment directories.
      DESC
      task :directories, :except => { :no_release => true } do
        dirs = [deploy_to, releases_path, shared_path]
        dirs += %w(backups uploads).map { |d| File.join(shared_path, d) }
        run "umask 02 && mkdir -p #{dirs.join(' ')}"
      end

      desc <<-DESC
        [internal] Writes a script to restore a database backup.
      DESC
      task :restore, :except => { :no_release => true } do
        put <<-END.gsub(/^ */, ''), "#{shared_path}/backups/restore", :mode => 0755
          #!/bin/sh
          gzcat $1 | mysql -u #{database_username} -p #{database_name}
        END
      end

      desc <<-DESC
        Creates a shared wp-config.php.
      DESC
      task :config, :except => { :no_release => true } do
        require 'digest/sha1'
        wp_config = Wordpress.config(:db_name     => database_name,
                                     :db_user     => database_username,
                                     :db_password => database_password,
                                     :secret_key  => Digest::SHA1.hexdigest(rand.to_s),
                                     :abspath     => '/../current/public/')

        put wp_config, "#{shared_path}/wp-config.php", :mode => 0600
      end
    end

    desc <<-DESC
      [internal] Copies your project to the remote servers. This is the first stage \
      of any deployment; moving your updated code and assets to the deployment \
      servers. You will rarely call this task directly, however; instead, you \
      should call the `deploy' task (to do a complete deploy) or the `update' \
      task (if you want to perform the `restart' task separately).

      You will need to make sure you set the :scm variable to the source \
      control software you are using (it defaults to :subversion), and the \
      :deploy_via variable to the strategy you want to use to deploy (it \
      defaults to :checkout).
    DESC
    task :update_code, :except => { :no_release => true } do
      on_rollback { run "rm -rf #{release_path}; true" }
      strategy.deploy!
      finalize_update.default
    end

    namespace :finalize_update do
      desc <<-DESC
        [internal] Touches up the released code. This is called by update_code \
        after the basic deploy finishes.

        This task will make the release group-writable (if the :group_writable \
        variable is set to true, which is the default). It will then set up \
        symlinks to the shared directory for the uploads directory.
      DESC
      task :default, :except => { :no_release => true } do
        chmod
        symlink_shared_paths
        config
      end

      desc <<-DESC
        [internal] Makes the release group writable, if desired.
      DESC
      task :chmod, :except => { :no_release => true } do
        run "chmod -fR g+w #{latest_release}" if fetch(:group_writable, true)
      end

      desc <<-DESC
        [internal] Symlinks shared paths, like uploads, into the release.
      DESC
      task :symlink_shared_paths, :except => { :no_release => true } do
        run <<-CMD
          rm -rf #{latest_release}/public/wp-content/uploads &&
          ln -s #{shared_path}/uploads #{latest_release}/public/wp-content/uploads
        CMD
      end

      desc <<-DESC
        [internal] Symlinks the shared wp-config.php into the release.
      DESC
      task :config, :except => { :no_release => true } do
        run <<-CMD
          rm -f #{latest_release}/public/wp-config.php &&
          ln -s #{shared_path}/wp-config.php #{latest_release}/public/wp-config.php
        CMD
      end
    end

    desc <<-DESC
      [internal] Updates the symlink to the most recently deployed version. Capistrano works \
      by putting each new release of your application in its own directory. When \
      you deploy a new version, this task's job is to update the `current' symlink \
      to point at the new version. You will rarely need to call this task \
      directly; instead, use the `deploy' task (which performs a complete \
      deploy, including `restart') or the 'update' task (which does everything \
      except `restart').
    DESC
    task :symlink, :except => { :no_release => true } do
      on_rollback { run "rm -f #{current_path}; ln -s #{previous_release} #{current_path}; true" }
      run "rm -f #{current_path} && ln -s #{latest_release} #{current_path}"
    end

    desc <<-DESC
      Rolls back to a previous version. This is handy if you ever \
      discover that you've deployed a lemon; `cap rollback' and you're right \
      back where you were, on the previously deployed version.
    DESC
    task :rollback do
      if releases.length < 2
        abort "could not rollback the code because there is no prior release"
      else
        run "rm #{current_path}; ln -s #{previous_release} #{current_path} && rm -rf #{current_release}"
      end
    end

    namespace :database do
      desc <<-DESC
        Backup the database. This is HIGHLY recommended before upgrading \
        Wordpress.

        Backups may be restored manually by running
          \#{shared_path}/backups/restore filename.sql.gz.
      DESC
      task :backup do
        run "mysqldump -u #{database_username} -p#{database_password} --compress --opt --lock-tables=false --skip-add-locks --skip-extended-insert #{database_name} | gzip > #{shared_path}/backups/#{release_name}.sql.gz"
      end
    end

    namespace :plugins do
      desc 'Disable all plugins.'
      task :disable do
        run "mysql -u #{database_username} -p#{database_password} -e 'update wp_options set option_value=\"a:0:{}\" where option_name=\"active_plugins\"' #{database_name}"
      end
    end

    desc 'Backup the database, disable all plugins, and deploy.'
    task :upgrade do
      database.backup
      plugins.disable
      deploy.default
      puts 'You should now visit wp-admin/upgrade.php and manually reactivate your plugins.'
    end

    desc <<-DESC
      Clean up old releases. By default, the last 5 releases are kept on each \
      server (though you can change this with the keep_releases variable). All \
      other deployed revisions are removed from the servers. By default, this \
      will use sudo to clean up the old releases, but if sudo is not available \
      for your environment, set the :use_sudo variable to false instead.
    DESC
    task :cleanup, :except => { :no_release => true } do
      count = fetch(:keep_releases, 5).to_i
      if count >= releases.length
        logger.important "no old releases to clean up"
      else
        logger.info "keeping #{count} of #{releases.length} deployed releases"

        directories = (releases - releases.last(count)).map { |release|
          File.join(releases_path, release) }.join(" ")

        invoke_command "rm -rf #{directories}", :via => run_method
      end
    end

    namespace :pending do
      desc <<-DESC
        Displays the `diff' since your last deploy. This is useful if you want \
        to examine what changes are about to be deployed. Note that this might \
        not be supported on all SCM's.
      DESC
      task :diff, :except => { :no_release => true } do
        system(source.local.diff(current_revision))
      end

      desc <<-DESC
        Displays the commits since your last deploy. This is good for a summary \
        of the changes that have occurred since the last deploy. Note that this \
        might not be supported on all SCM's.
      DESC
      task :default, :except => { :no_release => true } do
        from = source.next_revision(current_revision)
        system(source.local.log(from))
      end
    end
  end
end