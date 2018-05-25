Gem::Specification.new do |s|
  s.name = 'binproxy'
  s.executables << 'binproxy'
  s.version = '1.0.0'
  s.date = '2016-08-05'
  s.summary = 'BinProxy'
  s.description = 'A BinData-powered intercepting proxy for arbitrary TCP streams'
  s.homepage = 'https://github.com/nccgroup/BinProxy'
  s.author = 'Ryan Koppenhaver'
  s.email = 'ryan.koppenhaver@nccgroup.trust'
  s.files = Dir['{lib,public,views}/**/*']

  s.add_development_dependency "bundler", "~> 1.3"
  s.add_development_dependency "rspec", "~> 3.1.0"
  s.add_development_dependency "kramdown" # for previewing the README file
  s.add_development_dependency "rerun"
  s.add_development_dependency "pry"
  s.add_development_dependency "licensed"
  # These two are incompatible.
  #s.add_development_dependency "pry-byebug"
  #s.add_development_dependency "pry-remote-em"

  s.add_runtime_dependency 'thin', '~>1.7.2'
  s.add_runtime_dependency 'activesupport', '~> 4.2.0'
  s.add_runtime_dependency 'bindata', '~> 2.1.0'
  s.add_runtime_dependency 'eventmachine', '~> 1.0.4'
  s.add_runtime_dependency 'rbkb', '~> 0.7.2'
  s.add_runtime_dependency 'sinatra', '~> 2.0.1'
  s.add_runtime_dependency 'sinatra-websocket', '~> 0.3.1'
  s.add_runtime_dependency 'trollop', '~> 2.1.1'
  s.add_runtime_dependency 'sass', '~> 3.4.9'
  s.add_runtime_dependency 'haml', '~> 4.0.6'
  s.add_runtime_dependency 'colorize', '~> 0.7.5'
  s.add_runtime_dependency 'clipboard','~> 1.0.5'

  #XXX not realy a BP dep, used for a parser
  s.add_runtime_dependency 'msgpack'
end
