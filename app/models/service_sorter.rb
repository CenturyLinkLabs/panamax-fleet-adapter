require 'set'

module FleetAdapter
  module Models
    class ServiceSorter
      class << self
        def sort(services)
          @services = services
          @unmarked = Array.new(@services)
          @temporary_marked = Set.new
          @sorted_services = []

          until @unmarked.empty?
            visit(@unmarked[-1])
          end

          @sorted_services
        end

        private

        def visit(n)
          if @temporary_marked.include?(n.name)
            if get_service_names_for(n.links).include?(n.name)
              raise ArgumentError, "An image can not link to itself: #{n.name}"
            else
              raise ArgumentError, "Circular import between #{n.name} and #{@temporary_marked}"
            end
          end

          if @unmarked.include?(n)
            @temporary_marked.add(n.name)
            @services.each do |service|
              if get_service_names_for(service.links).include?(n.name)
                n.dependency = true
                service.dependencies << n
                visit(service)
              end
            end
            @temporary_marked.delete(n.name)
            @unmarked.delete(n)
            @sorted_services.insert(0, n)
          end
        end

        def get_service_names_for(links)
          links ||= []
          links.map { |link| link[:name].downcase }
        end
      end
    end
  end
end
