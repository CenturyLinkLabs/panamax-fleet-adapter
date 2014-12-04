module FleetAdapter
  module Models
    class ServiceMediator
      def initialize(services_attrs=[])
        @services_attrs = services_attrs
        @services = []
      end

      def load_and_start_all
        create_all
        @services.each { |service| load_service(service) }.each { |service| start(service.id) }
      end

      def status_for(id)
        if status = fleet.status(id)
          status.select! { |k, _| %i(active_state load_state sub_state).include?(k) }
          status.each_with_object('') { |(k, v), state| state << "#{k}: #{v}; " }.chomp('; ')
        else
          'error'
        end
      end

      def start(id)
        fleet.start(id)
      end

      def stop(id)
        fleet.stop(id)
      end

      def destroy(id)
        fleet.destroy(id)
      end

      private

      def create_all
        service_prototypes.each do |proto|
          if proto.deployment_count == 1
            @services << proto.clone
          else
            proto.deployment_count.times do |i|
              @services << proto.clone.tap { |service| service.name = "#{proto.name}@#{i + 1}" }
            end
          end
        end
      end

      def service_prototypes
        services = @services_attrs.map { |service_attrs| Service.new(service_attrs) }
        services = ServiceLinker.link(services)
        ServiceSorter.sort(services)
      end

      def load_service(service)
        fleet.load(service.id, ServiceConverter.new(service).service_def)
      end

      def fleet
        @fleet ||= Fleet.new(fleet_api_url: ENV['FLEETCTL_ENDPOINT'])
      end
    end
  end
end
