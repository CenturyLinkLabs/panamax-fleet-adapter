module FleetAdapter
  module Models
    class ServiceSorter
      require 'set'

      class << self

        def sort(services)
          @services = services
          @unmarked = Array.new(@services)
          @temporary_marked = Set.new
          @sorted_services = []

          until @unmarked.empty?
            visit(@unmarked[-1])
          end

          return @sorted_services
        end

        private

        def visit(n)
          if @temporary_marked.include?(n[:name])
            if get_service_names_for(n[:links]).include?(n[:name])
              raise ArgumentError, "An image can not link to itself: #{n[:name]}"
            else
              raise ArgumentError, "Circular import between #{n[:name]} and #{@temporary_marked}"
            end
          end

          if @unmarked.include?(n)
            @temporary_marked.add(n[:name])
            @services.each do |service|
              if get_service_names_for(service[:links]).include?(n[:name])
                # There should be only one instance of a dependent service
                limit_deployment_count(n)
                set_link_port_and_protocol(service, n)
                visit(service)
              end
            end
            @temporary_marked.delete(n[:name])
            @unmarked.delete(n)
            @sorted_services.insert(0, n)
          end
        end

        def get_service_names_for(links)
          links ||= []
          links.map { |link| link[:name] }
        end

        def limit_deployment_count(service)
          service[:deployment] ||= {}
          service[:deployment][:count] = 1
        end

        # Sets the minimum port and its protocol on the service link to a dependency
        def set_link_port_and_protocol(service, dependency)
          return if service[:links].to_a.empty?

          exposed_ports = ports_and_protocols_for(dependency)
          unless min_port = exposed_ports.sort_by { |exposed_port| exposed_port[:port] }.first
            raise ArgumentError, "#{dependency[:name]} does not expose a port"
          end

          service[:links].find { |link| link[:name] == dependency[:name] }
                         .merge!({ port: min_port[:port], protocol: min_port[:protocol] })
        end

        # Finds the explicitly exposed ports (:ports and :expose) on the dependency and
        # creates a hash of the port and protocol for each
        def ports_and_protocols_for(service)
          return [] unless service.has_key?(:ports)

          ports = service[:ports].map do |exposed_port|
            { port: exposed_port[:hostPort], protocol: (exposed_port[:protocol] || 'tcp') }
          end

          if service[:expose]
            exposed_ports = service[:expose].map do |exposed_port|
              { port: exposed_port, protocol: 'tcp' }
            end
            ports.push(exposed_ports).flatten!
          end

          return ports
        end

      end
    end
  end
end
