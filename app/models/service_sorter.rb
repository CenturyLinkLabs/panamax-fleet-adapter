require 'set'

module FleetAdapter
  module Models
    class ServiceSorter

      def self.sort(services)
        new(services).sort
      end

      def initialize(services)
        @services = services
        @unmarked = Array.new(@services)
        @temporary_marked = Set.new
        @sorted_services = []
      end

      def sort
        until @unmarked.empty?
          visit(@unmarked[-1])
        end

        @sorted_services
      end

      private

      def visit(service)
        if @temporary_marked.include?(service)
          raise ArgumentError, 'circular reference'
        end

        if @unmarked.include?(service)
          @temporary_marked.add(service)
          service.links.each { |link| visit(link[:service]) }
          @temporary_marked.delete(service)

          @unmarked.delete(service)
          @sorted_services.insert(-1, service)
        end
      end
    end
  end
end
