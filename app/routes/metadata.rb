module FleetAdapter
  module Routes
    class Metadata < Base
      get "/#{API_VERSION}/metadata" do
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
