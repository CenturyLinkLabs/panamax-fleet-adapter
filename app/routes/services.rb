require 'app/models/service'
require 'fleet'

module FleetAdapter
  class Services < Sinatra::Application

    before do
      headers 'Content-Type' => 'application/json'
    end

    before do
      @payload = JSON.parse(request.body.read) rescue nil
    end

    error Fleet::NotFound do
      status 404
    end

    post '/services' do
      services = @payload.map do |service|
        Service.create(service)
      end

      services.each(&:start)

      result = services.map do |service|
        { id: service.id }
      end

      status 201
      json result
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

      case @payload['desiredState']
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
