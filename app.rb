require 'rubygems'
require 'bundler'
require 'fleet'

# Setup load paths
Bundler.require
$: << File.expand_path('../', __FILE__)

Fleet.configure do |config|
  config.fleet_api_url = ENV['FLEETCTL_ENDPOINT']
end

# Require base
require 'sinatra/base'

require 'app/models'
require 'app/routes'

module FleetAdapter
  class App < Sinatra::Application
    configure do
      disable :method_override
      disable :static
    end

    use FleetAdapter::Routes::Healthcheck
    use FleetAdapter::Routes::Services
  end
end

include FleetAdapter::Models
