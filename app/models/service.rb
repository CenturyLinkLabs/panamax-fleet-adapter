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

        # ip_address = host ip_address or name %H
        # port = this container's min_port
        # service_block = {}
        #
        # links.each do |link|
        #   # force fleet to run this in bin/bash/
        #   service_block[:Environment] = "\"SERVICE_HOST=`/usr/bin/etcdctl get app/#{link[:name].upcase}@1_SERVICE_HOST`\""
        #   service_block['Environment'] = "\"SERVICE_PORT=`/usr/bin/etcdctl get app/#{link[:name].upcase}@1_SERVICE_PORT`\""
        # end

        service_block = {
          # A hack to be able to have two ExecStartPre values
          'EnvironmentFile'=>'/etc/environment',
          :ExecStartPre => "-/bin/bash -c \"/usr/bin/etcdctl set app/#{name.upcase}_SERVICE_HOST ${COREOS_PUBLIC_IPV4} && /usr/bin/etcdctl set app/#{name.upcase}_SERVICE_PORT #{min_port}\"",
          'ExecStartPre' => "-/usr/bin/docker pull #{source}",
          'ExecStart' => "-/bin/bash -c \"#{docker_run_string}\"",
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

      def min_port
        ports.sort_by { |port_binding| port_binding[:hostPort]}.first[:hostPort]
      end

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

          links.each do |link|

            service_host, service_port, port = {}, {}, {}

            service_host[:variable] = (link[:alias] ? "#{link[:alias]}_service_host" : "#{link[:name]}_service_host").upcase
            service_host[:value] = "`/usr/bin/etcdctl get app/#{link[:name].upcase}@1_SERVICE_HOST`"
            environment.push(service_host)

            service_port[:variable] = (link[:alias] ? "#{link[:alias]}_service_port" : "#{link[:name]}_service_port").upcase
            service_port[:value] = "`/usr/bin/etcdctl get app/#{link[:name].upcase}@1_SERVICE_PORT`"
            environment.push(service_port)

            port[:variable] = (link[:alias] ? "#{link[:alias]}_port" : "#{link[:name]}_port").upcase
            port[:value] = "#{link[:protocol]}://`/usr/bin/etcdctl get app/#{link[:name].upcase}@1_SERVICE_HOST`:`/usr/bin/etcdctl get app/#{link[:name].upcase}@1_SERVICE_PORT`"
            environment.push(port)

        end

        environment.map { |env| "-e #{env[:variable]}=#{env[:value]}" }
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
