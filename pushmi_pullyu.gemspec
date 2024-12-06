lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pushmi_pullyu/version'

Gem::Specification.new do |spec|
  spec.name          = 'pushmi_pullyu'
  spec.version       = PushmiPullyu::VERSION
  spec.authors       = ['Shane Murnaghan', 'Omar Rodriguez-Arenas']
  spec.email         = ['murnagha@ualberta.ca', 'orodrigu@ualberta.ca']

  spec.summary       = 'Ruby application to manage flow of content from Jupiter into Swift for preservation'
  spec.homepage      = 'https://github.com/ualbertalib/pushmi_pullyu'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.7'

  spec.add_dependency 'activesupport', '>= 5', '< 8.1'
  spec.add_dependency 'bagit', '~> 0.4'
  spec.add_dependency 'connection_pool', '~> 2.2'
  spec.add_dependency 'daemons', '~> 1.2', '>= 1.2.4'
  spec.add_dependency 'minitar', '>= 0.7', '< 1.0'
  spec.add_dependency 'openstack', '~> 3.3', '>= 3.3.10'
  spec.add_dependency 'rdf', '>= 1.99', '< 3.3'
  spec.add_dependency 'rdf-n3', '>= 1.99', '< 3.3'
  spec.add_dependency 'redis', '>= 3.3', '< 6.0'
  spec.add_dependency 'rest-client', '>= 1.8', '< 3.0'
  spec.add_dependency 'rollbar', '>= 2.18', '< 4.0'
  spec.add_dependency 'securerandom', '~> 0.3.2'
  spec.add_dependency 'uuid', '~> 2.3.9'

  spec.metadata = {
    'rubygems_mfa_required' => 'true'
  }
end
