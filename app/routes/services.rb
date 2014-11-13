require 'app/models/service'
require 'app/models/service_sorter'
require 'fleet'

module FleetAdapter
  module Routes
    class Services < Base

      namespace '/' + API_VERSION do
        post '/services' do
          sorted_services = ServiceSorter.sort(@payload)
          services = Service.create_all(sorted_services)
          services.each(&:start)
          status 201
          json services.map { |service| { id: service.id } }
        end

        get '/services/:id' do
          service = Service.find(params[:id])

          result = {
            id: service.id,
            'actualState' => service.status
          }

          json result
        end

        put '/services/:id' do
          service = Service.find(params[:id])

          case @payload[:desiredState]
          when 'started'
            service.start
            status 204
          when 'stopped'
            service.stop
            status 204
          else
            status 400
          end
        end

        delete '/services/:id' do
          Service.find(params[:id]).destroy
          status 204
        end
      end
    end
  end
end
