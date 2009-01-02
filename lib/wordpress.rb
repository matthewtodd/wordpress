require 'wordpress/release'

module Wordpress #:nodoc:
  VERSION = '0.6.0'

  def self.config(options={})
    config = release.contents('wp-config-sample.php')
    options.each do |key, value|
      config.sub! /'#{key.to_s.upcase}',(.*?)'.*?'/m do |match|
        "'#{key.to_s.upcase}',#{$1}'#{value}'"
      end
    end
    config
  end

  def self.release
    @@release ||= Release.new
  end
end

require 'wordpress/cli'