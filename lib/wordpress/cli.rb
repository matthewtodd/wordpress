require 'digest/sha1'
require 'wordpress/release'

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
    attr_reader :base
    
    def initialize(*argv)
      abort "Please specify the directory set up, e.g. #{File.basename($0)} ." if argv.empty?
      abort 'Too many arguments; please specify only the directory to set up.' if argv.length > 1
      @base = File.expand_path(argv.shift)
    end
    
    def run
      directory(base) do
        file 'Capfile', <<-END
          %w( rubygems wordpress ).each { |lib| require lib }
          load Gem.required_location('wordpress', 'wordpress/recipes/deploy.rb')
          load 'config/deploy'
        END
        
        directory('config') do
          file 'boot.rb', <<-END
            %w( rubygems wordpress ).each { |lib| require lib }
            WORDPRESS_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))
          END
          
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
          
          file 'lighttpd.conf', <<-END
            server.port = 3000
            
            var.root                 = env.WORDPRESS_ROOT
            server.document-root     = var.root + "/public"
            index-file.names         = ( "index.php" )
            server.error-handler-404 = "/index.php"

            include "lighttpd-mimetypes.conf"
            
            server.modules = ( "mod_fastcgi" )
            fastcgi.server = ( ".php" => (( 
                                 "bin-path" => env.PHP_FASTCGI,
                                 "socket"   => var.root + "/tmp/php.socket"
                             )))
            END
          
          file 'lighttpd-mimetypes.conf', <<-END
            mimetype.assign             = (
              ".pdf"          =>      "application/pdf",
              ".sig"          =>      "application/pgp-signature",
              ".spl"          =>      "application/futuresplash",
              ".class"        =>      "application/octet-stream",
              ".ps"           =>      "application/postscript",
              ".torrent"      =>      "application/x-bittorrent",
              ".dvi"          =>      "application/x-dvi",
              ".gz"           =>      "application/x-gzip",
              ".pac"          =>      "application/x-ns-proxy-autoconfig",
              ".swf"          =>      "application/x-shockwave-flash",
              ".tar.gz"       =>      "application/x-tgz",
              ".tgz"          =>      "application/x-tgz",
              ".tar"          =>      "application/x-tar",
              ".zip"          =>      "application/zip",
              ".mp3"          =>      "audio/mpeg",
              ".m3u"          =>      "audio/x-mpegurl",
              ".wma"          =>      "audio/x-ms-wma",
              ".wax"          =>      "audio/x-ms-wax",
              ".ogg"          =>      "application/ogg",
              ".wav"          =>      "audio/x-wav",
              ".gif"          =>      "image/gif",
              ".jpg"          =>      "image/jpeg",
              ".jpeg"         =>      "image/jpeg",
              ".png"          =>      "image/png",
              ".xbm"          =>      "image/x-xbitmap",
              ".xpm"          =>      "image/x-xpixmap",
              ".xwd"          =>      "image/x-xwindowdump",
              ".css"          =>      "text/css",
              ".html"         =>      "text/html",
              ".htm"          =>      "text/html",
              ".js"           =>      "text/javascript",
              ".asc"          =>      "text/plain",
              ".c"            =>      "text/plain",
              ".cpp"          =>      "text/plain",
              ".log"          =>      "text/plain",
              ".conf"         =>      "text/plain",
              ".text"         =>      "text/plain",
              ".txt"          =>      "text/plain",
              ".dtd"          =>      "text/xml",
              ".xml"          =>      "text/xml",
              ".mpeg"         =>      "video/mpeg",
              ".mpg"          =>      "video/mpeg",
              ".mov"          =>      "video/quicktime",
              ".qt"           =>      "video/quicktime",
              ".avi"          =>      "video/x-msvideo",
              ".asf"          =>      "video/x-ms-asf",
              ".asx"          =>      "video/x-ms-asf",
              ".wmv"          =>      "video/x-ms-wmv",
              ".bz2"          =>      "application/x-bzip",
              ".tbz"          =>      "application/x-bzip-compressed-tar",
              ".tar.bz2"      =>      "application/x-bzip-compressed-tar",
              # default mime type
              ""              =>      "application/octet-stream",
             )
          END
          
          file 'wp-config-sample.php', Wordpress.config(:db_name     => File.basename(base),
                                                        :db_user     => 'root',
                                                        :db_password => '',
                                                        :secret_key  => Digest::SHA1.hexdigest(rand.to_s),
                                                        :abspath     => '/../public/')
        end
        
        directory('public') do
          Wordpress.release.upgrade
          system 'rm', 'wp-config-sample.php'
          symlink '../config/wp-config.php'
        end
        
        directory('script') do
          file 'server', <<-END, :mode => 0755
            #!/usr/bin/env ruby
            require File.join(File.dirname(__FILE__), '..', 'config', 'boot')
            require 'wordpress/servers/lighttpd'
          END
        end
      end
    end
    
    private
    
    def directory(path)
      system 'mkdir', '-p', path
      Dir.chdir(path) { yield }
    end
    
    def file(path, contents, options={})
      indent = contents.scan(/^ +/m).first
      contents.gsub! /^#{indent}/, ''
      File.open(path, 'w') { |f| f.write(contents) } unless File.exists?(path)
      File.chmod(options[:mode], path) if options[:mode]
    end
    
    def symlink(file)
      system 'ln', '-sf', file
    end
  end
end