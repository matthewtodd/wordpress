require 'rake/rdoctask'

$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'wordpress'

spec = Gem::Specification.new do |spec|
  spec.name             = 'wordpress'
  spec.version          = Wordpress::VERSION
  spec.summary          = 'Automates creating, upgrading and deploying a Wordpress installation.'
  spec.files            = FileList['*.rdoc', 'bin/*', 'lib/**/*.rb'].to_a
  spec.executables      = ['wordpressify']
  spec.has_rdoc         = true
  spec.rdoc_options     = %W[--main README.rdoc --title #{spec.name}-#{spec.version} --inline-source --line-numbers --all]
  spec.extra_rdoc_files = FileList['*.rdoc'].to_a
  spec.author           = 'Matthew Todd'
  spec.email            = 'matthew.todd@gmail.com'

  spec.add_dependency     'capistrano', '>= 2.5.1'
  spec.add_dependency     'matthewtodd-wordpress-release'
end

desc 'Generate a gemspec file'
task :gemspec do
  File.open("#{spec.name}.gemspec", 'w') do |f|
    f.write spec.to_ruby
  end
end

desc 'Generate documentation'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir   = 'docs'
  rdoc.options    = spec.rdoc_options
  rdoc.rdoc_files = spec.files
end
