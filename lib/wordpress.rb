module Wordpress #:nodoc:
  TARBALL = File.join(File.dirname(__FILE__), '..', 'resources', 'wordpress-2.5.tar.gz')
  VERSION = '0.3.2'
  
  def self.config(options={})
    config = `tar zxfO #{TARBALL} 'wordpress/wp-config-sample.php'`
    options.each do |key, value|
      config.sub! /'#{key.to_s.upcase}',(.*?)'.*?'/m do |match|
        "'#{key.to_s.upcase}',#{$1}'#{value}'"
      end
    end
    config
  end
end

require 'wordpress/cli'