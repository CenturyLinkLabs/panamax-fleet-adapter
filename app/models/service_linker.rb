module FleetAdapter
  module Models
    class ServiceLinker
      using FleetAdapter::StringExtensions

      def self.link(services)
        new(services).link
      end

      def initialize(services)
        @services = services
      end

      def link
        @services.each do |parent_service|
          parent_service.links.each do |link|
            child_service = find_service(link[:name])

            unless child_service.linkable?
              raise ArgumentError, "#{child_service.name} does not have an explicit port binding"
            end

            # Any service that is a dependency must have a deploy count of 1
            child_service.deployment_count = 1

            link[:service] = child_service
          end
        end
      end

      private

      def find_service(name)
        @services.find do |service|
          service.name.downcase == name.sanitize.downcase
        end
      end
    end
  end
end
