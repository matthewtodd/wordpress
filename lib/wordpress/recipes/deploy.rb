puts '-' * 72
puts 'DEPRECATION WARNING'
puts '-' * 72
puts 'wordpress/recipes/deploy will be removed in a future version.'
puts 'Please adjust your Capfile to look like this:'
puts ''
puts "require 'rubygems'"
puts "require 'wordpress'"
puts "load 'deploy'"
puts "load 'deploy/wordpress'"
puts "load 'config/deploy'"
puts ''

load 'deploy'
load 'deploy/wordpress'
