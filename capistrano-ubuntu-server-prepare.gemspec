# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "capistrano3-ubuntu-server-prepare"
  spec.version       = "0.0.3"
  spec.authors       = ["goooseman"]
  spec.email         = ["inbox@goooseman.ru"]
  spec.summary       = "A task for Capistrano v3 to prepare Ubuntu 14.04 server for first deployment"
  spec.description   = "Can install nginx, ngx_pagespeed, postgreSQL, Redis, RVM, Ruby, Rails, Bundler. See homepage for additional inforation and instructions."
  spec.homepage      = "http://github.com/goooseman/capistrano3-ubuntu-server-prepare"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.require_paths = ["lib"]

  spec.add_dependency "highline"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_runtime_dependency 'capistrano', '~> 3.1', '>= 3.1.0'
end
