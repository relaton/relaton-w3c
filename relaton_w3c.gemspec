require_relative 'lib/relaton_w3c/version'

Gem::Specification.new do |spec|
  spec.name          = "relaton-w3c"
  spec.version       = RelatonW3c::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = "RelatonIso: retrieve W3C Standards for bibliographic use "\
                       "using the IsoBibliographicItem model"
  spec.description   = "RelatonIso: retrieve W3C Standards for bibliographic use "\
                       "using the IsoBibliographicItem model"
  spec.homepage      = "https://github.com/relaton/relaton-wc3"
  spec.license       = "BSD-2-Clause"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "debase"
  spec.add_development_dependency "equivalent-xml", "~> 0.6"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "ruby-debug-ide"
  spec.add_development_dependency "ruby-jing"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "webmock"

  spec.add_dependency "relaton-iso-bib", "~> 0.8.0"
end
