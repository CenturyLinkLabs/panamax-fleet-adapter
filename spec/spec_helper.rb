require 'its'
require 'rack/test'

require File.expand_path '../../app.rb', __FILE__

ENV['RACK_ENV'] = 'test'

module ApiType
  include Rack::Test::Methods

  def app
    FleetAdapter::App
  end
end

RSpec.configure do |c|
  c.include ApiType, type: :api, file_path: %r(spec/api)
end
