module FleetAdapter
  module Routes
    class Healthcheck < Base

      get '/healthcheck' do
        headers 'Content-Type' => 'text/plain'

        begin
          Fleet.new.list_machines
          'true'
        rescue
          'false'
        end
      end

    end
  end
end
