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

def fixture_data(filename, path='support/fixtures')
  filename += '.json' if File.extname(filename).empty?
  file_path = File.expand_path(File.join(path, filename), __dir__)
  File.read(file_path).gsub(/\s+/, '')
end

def hash_from_fixture(filename, path='support/fixtures')
  JSON.parse(fixture_data(filename, path), :symbolize_names => true)
end
