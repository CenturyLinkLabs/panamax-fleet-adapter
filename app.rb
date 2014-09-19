require 'rubygems'
require 'bundler'

# Setup load paths
Bundler.require
$: << File.expand_path('../', __FILE__)

# Require base
require 'sinatra/base'

require 'app/routes/services'

module FleetAdapter
  class App < Sinatra::Application
    configure do
      disable :method_override
      disable :static
    end

    use Services
  end
end
