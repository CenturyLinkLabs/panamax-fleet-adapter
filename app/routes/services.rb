require 'app/models/service'
require 'app/models/service_converter'
require 'app/models/service_mediator'
require 'app/models/service_sorter'
require 'fleet'

module FleetAdapter
  module Routes
    class Services < Base

      namespace '/' + API_VERSION do
        post '/services' do
          services = service_mediator.load_and_start_all
          status 201
          json services.map { |service| { id: service.id } }
        end

        get '/services/:id' do
          result = {
            id: params[:id],
            'actualState' => service_mediator.status_for(params[:id])
          }

          json result
        end

        put '/services/:id' do
          case @payload[:desiredState]
          when 'started'
            service_mediator.start(params[:id])
            status 204
          when 'stopped'
            service_mediator.stop(params[:id])
            status 204
          else
            status 400
          end
        end

        delete '/services/:id' do
          service_mediator.destroy(params[:id])
          status 204
        end
      end

      def service_mediator
        ServiceMediator.new(@payload)
      end
    end
  end
end
