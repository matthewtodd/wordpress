require 'digest/sha1'

module Wordpress
  # Sets up a new project or upgrades the Wordpress installation in an
  # existing project.
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
          %w(rubygems wordpress).each { |lib| require lib }
          require 'wordpress/recipes/deploy'
          load 'config/deploy'
        END

        directory('config') do
          file 'boot.rb', <<-END
            %w( rubygems wordpress ).each { |lib| require lib }
            WORDPRESS_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))
          END

          file 'deploy.rb', <<-END
            set :application,       'set your application name here'
            set :repository,        'set your repository location here'
            set :database_name,     'set your database name here'
            set :database_username, 'set your database username here'

            # If you aren't deploying to /u/apps/\#{application} on the target
            # servers (which is the default), you can specify the actual location
            # via the :deploy_to variable:
            # set :deploy_to, "/var/www/\#{application}"

            # If you aren't using Subversion to manage your source code, specify
            # your SCM below:
            # set :scm, :git
            # set :git_shallow_clone, 1

            server 'your server here', :web, :app, :db, :primary => true
          END

          file 'lighttpd.conf', <<-END
            server.port              = 3000

            var.root                 = env.WORDPRESS_ROOT
            server.document-root     = var.root + "/public"
            server.error-handler-404 = "/index.php"
            server.modules           = ( "mod_fastcgi" )
            index-file.names         = ( "index.php" )
            fastcgi.server           = ( ".php" => ((
                                           "bin-path" => env.PHP_FASTCGI,
                                           "socket"   => var.root + "/tmp/sockets/php"
                                       )))

            include "lighttpd-mimetypes.conf"
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

          config = Wordpress.config(:db_name     => File.basename(base),
                                    :db_user     => 'root',
                                    :db_password => '',
                                    :secret_key  => Digest::SHA1.hexdigest(rand.to_s),
                                    :abspath     => '/../public/')

          file 'wp-config.php', config
          file 'wp-config-sample.php', config
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