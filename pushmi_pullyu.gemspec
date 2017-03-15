# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pushmi_pullyu/version'

Gem::Specification.new do |spec|
  spec.name          = 'pushmi_pullyu'
  spec.version       = PushmiPullyu::VERSION
  spec.authors       = ['Shane Murnaghan']
  spec.email         = ['murnagha@ualberta.ca']

  spec.summary       = 'Ruby application to manage flow of content from Fedora into Swift for preservation'
  spec.homepage      = 'https://github.com/ualbertalib/pushmi_pullyu'
  spec.license       = 'MIT'

  spec.files = Dir['README.md', 'LICENSE.txt', 'Rakefile', 'bin/*', 'lib/**/*.rb']

  spec.executables = ['pushmi_pullyu']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.45'
end
