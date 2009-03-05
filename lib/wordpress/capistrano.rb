# Add our recipies directory to Capistrano's load_path.
if defined?(Capistrano)
  config = Capistrano::Configuration.instance
  config.load_paths << File.expand_path(File.join(File.dirname(__FILE__), 'recipes')) unless config.nil?
end
