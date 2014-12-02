require 'fleet'

module FleetAdapter
  module Models
    class Service
      using FleetAdapter::StringExtensions

      attr_accessor :name, :source, :command, :ports, :expose, :environment, :volumes, :deployment, :links,
                    :dependencies
      attr_writer :dependency

      def initialize(attrs)
        @id = attrs[:id]
        @name = attrs[:name].to_s.sanitize
        @source = attrs[:source]
        @links = attrs[:links] || []
        @command = attrs[:command]
        @ports = attrs[:ports] || []
        @expose = attrs[:expose] || []
        @environment = attrs[:environment] || []
        @volumes = attrs[:volumes] || []
        @deployment = attrs[:deployment] || { count: 1 }
        @dependencies = []
      end

      def id
        @id ||= "#{@name}.service"
      end

      def prefix
        @name.split('@').first
      end

      def dependency?
        @dependency
      end

      def deployment_count
        @deployment[:count].to_i
      end

      def clone
        super.tap do |clone|
          unless clone.links.empty?
            clone.dependencies.each do |dependency|
              set_link_port_and_protocol(dependency)
            end
          end
        end
      end

      protected

      # Sets the minimum port and its protocol on the service link to a dependency
      def set_link_port_and_protocol(dependency)
        raise ArgumentError, "#{dependency.name} does not have an explicit port binding" if dependency.ports.empty?

        exposed_ports = dependency.ports.map do |port|
          port.merge!(protocol: 'tcp') unless port.has_key?(:proto)
        end.flatten

        @links.find do |link|
          link[:name].sanitize.downcase == dependency.name.downcase
        end.merge!(exposed_ports: exposed_ports)
      end
    end
  end
end
