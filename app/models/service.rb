require 'fleet'

module FleetAdapter
  module Models
    class Service
      using FleetAdapter::StringExtensions

      attr_accessor :name, :source, :command, :ports, :expose, :environment, :volumes, :links

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
      end

      def id
        @id ||= "#{@name}.service"
      end

      def prefix
        @name.split('@').first
      end

      def deployment_count
        @deployment.fetch(:count, 1).to_i
      end

      def deployment_count=(count)
        @deployment[:count] = count
      end

      def linkable?
        !!(ports && ports.any?)
      end
    end
  end
end
