require 'tmpdir'

module Wordpress
  # ==Introduction
  # Creates a new Wordpress application with a default directory structure and
  # configuration at the path specified.
  #
  # May also be used to upgrade an existing Wordpress application.
  #
  # Generally aims to be well-behaved, but it's still wise to upgrade locally
  # using good version control (so you can, for example, <tt>git reset --hard
  # && git clean -fd</tt>). After upgrading locally, it's best to deploy using
  # <tt>deploy:upgrade</tt>, which will backup your database and disable your
  # plugins before deploying normally, {as
  # recommended}[http://codex.wordpress.org/Upgrading_WordPress_Extended].
  #
  # Currently uses Wordpress 2.5.
  #
  # ==Installation
  #  gem install wordpress --source http://gems.matthewtodd.org
  #
  # ==Usage
  #  wordpress /path/to/your/app
  class Cli
    attr_reader :base, :tmp
    
    def initialize(*argv)
      abort "Please specify the directory set up, e.g. #{File.basename($0)} ." if argv.empty?
      abort 'Too many arguments; please specify only the directory to set up.' if argv.length > 1
      
      @base    = argv.shift
      @tmp     = File.join(Dir.tmpdir, "wordpress.#{Process.pid}")
    end
    
    def run
      system 'mkdir', '-p', tmp
      system 'tar', 'zxf', Wordpress::TARBALL, '--directory', tmp

      directory(base) do
        file 'Capfile', <<-END
          %w( rubygems wordpress ).each { |lib| require lib }
          load Gem.required_location('wordpress', 'wordpress/recipes/deploy.rb')
          load 'config/deploy'
        END
        
        directory('config') do
          file 'deploy.rb', <<-END
            set :application, "set your application name here"
            set :repository,  "set your repository location here"

            # If you aren't deploying to /u/apps/\#{application} on the target
            # servers (which is the default), you can specify the actual location
            # via the :deploy_to variable:
            # set :deploy_to, "/var/www/\#{application}"

            # If you aren't using Subversion to manage your source code, specify
            # your SCM below:
            # set :scm, :subversion

            server "your server here", :web, :app, :db, :primary => true
          END
        end
        
        directory('public') do
          system 'rm', '-r', *wordpress_files if wordpress_files.any?
          system 'cp', '-r', File.join(tmp, 'wordpress', '.'), '.'
        end
      end

      system 'rm', '-r', tmp
    end
    
    private
    
    def directory(path)
      system 'mkdir', '-p', path
      Dir.chdir(path) { yield }
    end
    
    def file(path, contents)
      indent = contents.scan(/^ +/m).first
      contents.gsub! /^#{indent}/, ''
      File.open(path, 'w') { |f| f.write(contents) } unless File.exists?(path)
    end
    
    def wordpress_files
      # TODO if you look at this, even though it reads like the Wordpress
      # upgrade documentation, it's not particularly necessary now, is it?
      # delete these
      files = %w( readme.html index.php wp.php xmlrpc.php license.txt )
      files += Dir.glob('wp-*.php')
      files += Dir.glob('wp-admin')
      files += Dir.glob('wp-includes')

      # but don't delete these
      files -= %w( wp-config.php .htaccess robots.txt )
      files -= Dir.glob('wp-content')
      files -= Dir.glob('wp-images')

      # but do delete these
      files += Dir.glob('wp-content/themes/classic')
      files += Dir.glob('wp-content/themes/default')
      
      # if they exist
      files.select { |file| File.exist?(file) }
    end
  end
end