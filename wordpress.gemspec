# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{wordpress}
  s.version = "0.6.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Matthew Todd"]
  s.date = %q{2009-01-02}
  s.default_executable = %q{wordpressify}
  s.email = %q{matthew.todd@gmail.com}
  s.executables = ["wordpressify"]
  s.extra_rdoc_files = ["CHANGELOG.rdoc", "README.rdoc", "TODO.rdoc"]
  s.files = ["CHANGELOG.rdoc", "README.rdoc", "TODO.rdoc", "bin/wordpressify", "lib/wordpress/cli.rb", "lib/wordpress/recipes/deploy.rb", "lib/wordpress/servers/lighttpd.rb", "lib/wordpress.rb"]
  s.has_rdoc = true
  s.rdoc_options = ["--main", "README.rdoc", "--title", "wordpress-0.6.1", "--inline-source", "--line-numbers", "--all"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Automates creating, upgrading and deploying a Wordpress installation.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<capistrano>, [">= 2.2.0"])
      s.add_runtime_dependency(%q<matthewtodd-wordpress-release>, [">= 0"])
    else
      s.add_dependency(%q<capistrano>, [">= 2.2.0"])
      s.add_dependency(%q<matthewtodd-wordpress-release>, [">= 0"])
    end
  else
    s.add_dependency(%q<capistrano>, [">= 2.2.0"])
    s.add_dependency(%q<matthewtodd-wordpress-release>, [">= 0"])
  end
end
