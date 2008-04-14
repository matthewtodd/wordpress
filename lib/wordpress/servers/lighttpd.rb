unless File.exists?(File.join(WORDPRESS_ROOT, 'config', 'wp-config.php'))
  $stderr.puts "You'll need to set up config/wp-config.php before running the server."
  $stderr.puts "(Hint: config/wp-config-sample.php.)"
  exit 1
end

ENV['WORDPRESS_ROOT'] ||= WORDPRESS_ROOT
ENV['PHP_FASTCGI']    ||= `which php-cgi`.strip
Dir.mkdir(File.join(WORDPRESS_ROOT, 'tmp'))  unless File.exists?(File.join(WORDPRESS_ROOT, 'tmp'))
exec 'lighttpd', '-D', '-f', File.join(WORDPRESS_ROOT, 'config', 'lighttpd.conf'), *ARGV
