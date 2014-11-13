module FleetAdapter
  module Routes
    class Metadata < Base
      namespace '/' + API_VERSION do
        get '/metadata' do
          json(
            {
              version: FleetAdapter::VERSION,
              type: "Fleet"
            }
          )
        end
      end
    end
  end
end
