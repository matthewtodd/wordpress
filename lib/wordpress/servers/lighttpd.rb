ENV['WORDPRESS_ROOT'] ||= WORDPRESS_ROOT
ENV['PHP_FASTCGI']    ||= `which php-cgi`.strip
Dir.mkdir(File.join(WORDPRESS_ROOT, 'tmp'))  unless File.exists?(File.join(WORDPRESS_ROOT, 'tmp'))
exec 'lighttpd', '-D', '-f', File.join(WORDPRESS_ROOT, 'config', 'lighttpd.conf'), *ARGV
