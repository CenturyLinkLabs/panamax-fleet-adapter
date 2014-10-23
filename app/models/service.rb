require 'fleet'
require 'pry'

module FleetAdapter
  module Models
    class Service

      attr_accessor :id, :name, :source, :links, :command, :ports,
        :expose, :environment, :volumes, :deployment

      attr_reader :status

      def self.find(id)
        new('id' => id).tap(&:refresh)
      end

      def self.create_all(attrs)
        attrs.map { |service_attrs| self.create(service_attrs) }.flatten
      end

      def self.create(attrs)
        count = attrs.fetch(:deployment, {}).fetch(:count, 1)

        count.times.map do |i|
          new(attrs, i + 1).tap(&:load)
        end
      end

      def initialize(attrs, index=nil)
        self.id = attrs[:id]
        self.source = attrs[:source]
        self.links = attrs[:links] || []
        self.command= attrs[:command]
        self.ports = attrs[:ports] || []
        self.expose = attrs[:expose] || []
        self.environment = attrs[:environment] || []
        self.volumes = attrs[:volumes] || []
        self.deployment = attrs[:deployment] || {}

        if index
          self.name = "#{attrs[:name]}@#{index}"

          unless id
            self.id = "#{name}.service"
          end
        end

      end

      def load
        fleet.load(id, service_def)
      end

      def start
        fleet.start(id)
      end

      def stop
        fleet.stop(id)
      end

      def destroy
        fleet.destroy(id)
      end

      def refresh
        @status = case fleet.status(id)[:active_state]
        when 'active'
          'started'
        when 'failed'
          'stopped'
        else
          'error'
        end
      end

      def docker_run_string
        [
          '/usr/bin/docker run',
          '--rm',
          "--name #{name.split('@').first}",
          port_flags,
          expose_flags,
          environment_flags,
          volume_flags,
          source,
          command
        ].flatten.compact.join(' ').strip
      end

      def service_def
        unit_block = {}

        if links
          dep_services = links.map do |link|
            "#{link[:name]}@*.service"
          end.join(' ')

          unit_block['After'] = dep_services
          unit_block['Requires'] = dep_services
        end

        docker_rm = "-/usr/bin/docker rm #{name.split('@').first}"
        scheme, ip_address, port = ENV['FLEETCTL_ENDPOINT'].gsub('//', '').split(':')
        service_block = {
          # A hack to be able to have two ExecStartPre values
          ExecStartPre: "-/bin/bash -c \"/usr/bin/etcdctl set app/#{name.upcase}_HOST #{ip_address} && /usr/bin/etcdctl set app/#{name.upcase}_PORT #{port}\"",
          'ExecStartPre' => "-/usr/bin/docker pull #{source}",
          'ExecStart' => docker_run_string,
          'ExecStartPost' => docker_rm,
          'ExecStop' => "-/usr/bin/docker kill #{name.split('@').first}",
          'ExecStopPost' => docker_rm,
          'Restart' => 'always',
          'RestartSec' => '10',
          'TimeoutStartSec' => '5min'
        }

        fleet_block = {
          'Conflicts' => id.gsub(/@\d\./, "@*.")
        }

        {
          'Unit' => unit_block,
          'Service' => service_block,
          'X-Fleet' => fleet_block
        }
      end

      private

      def port_flags
        return unless ports
        ports.map do |port|
          option = '-p '
          if port[:hostInterface] || port[:hostPort]
            option << "#{port[:hostInterface]}:" if port[:hostInterface]
            option << "#{port[:hostPort]}:" unless port[:hostPort].to_s.empty?
          end
          option << "#{port[:containerPort]}"
          option << '/udp' if port[:protocol] && port[:protocol].upcase == 'UDP'
          option
        end
      end

      def expose_flags
        return unless expose
        expose.map { |exposed_port| "--expose #{exposed_port}" }
      end

      def environment_flags
        # add environment variables for linked services for etcd discovery
        attrs = %w(SERVICE_HOST SERVICE_PORT)

        attrs.each do |attr|
          links.each do |link|
            option = {}
            option[:variable] = (link[:alias] ? "#{link[:alias]}_#{attr}" : "#{link[:name]}_#{attr}").upcase
            option[:value] = "`/usr/bin/etcdctl get app/#{link[:name].upcase}@1_#{attr}`"
            environment.push(option)
          end
        end

        environment.map { |env| "-e \"#{env[:variable]}=#{env[:value]}\"" }
      end

      def volume_flags
        return unless volumes
        volumes.map do |volume|
          option = '-v '
          option << "#{volume[:hostPath]}:" if volume[:hostPath].present?
          option << volume[:containerPath]
          option
        end
      end

      def fleet
        @fleet ||= Fleet.new(fleet_api_url: ENV['FLEETCTL_ENDPOINT'])
      end
    end
  end
end
