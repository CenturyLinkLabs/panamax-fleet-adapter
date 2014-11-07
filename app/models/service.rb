require 'fleet'

module FleetAdapter
  module Models
    class Service

      using FleetAdapter::StringExtensions

      MAX_PORT = 65536

      attr_accessor :id, :name, :source, :links, :command, :ports,
        :expose, :environment, :volumes, :deployment, :prefix

      attr_reader :status

      def self.find(id)
        new(id: id).tap(&:refresh)
      end

      def self.create_all(attrs)
        attrs.map { |service_attrs| self.create(service_attrs) }.flatten
      end

      def self.create(attrs)
        count = attrs.fetch(:deployment, {}).fetch(:count, 1).to_i

        count.times.map do |i|
          new(attrs, i + 1).tap(&:load)
        end
      end

      def initialize(attrs, index=nil)
        self.name = attrs[:name].to_s.sanitize
        self.source = attrs[:source]
        self.links = attrs[:links] || []
        self.command= attrs[:command]
        self.ports = attrs[:ports] || []
        self.expose = attrs[:expose] || []
        self.environment = attrs[:environment] || []
        self.volumes = attrs[:volumes] || []
        self.deployment = attrs[:deployment] || {}
        self.prefix = self.name

        self.name += "@#{index}" if self.deployment[:count] && self.deployment[:count] != 1

        if attrs[:id]
          self.id = attrs[:id]
        else
          self.id = "#{name}.service"
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

      private

      def service_def
        {
          'Unit' => unit_block,
          'Service' => service_block,
          'X-Fleet' => fleet_block
        }
      end

      def unit_block
        unit_block = {}

        unless links.empty?
          dependencies = links.map do |link|
            "#{link[:name].sanitize}.service"
          end.join(' ')

          unit_block['After'] = dependencies
          unit_block['Wants'] = dependencies
        end

        return unit_block
      end

      def service_block
        docker_rm = "-/usr/bin/docker rm #{prefix}"
        service_registration = "/usr/bin/etcdctl set app/#{name.upcase}/#{name.upcase}_SERVICE_HOST ${COREOS_PRIVATE_IPV4}"
        if min_port
          service_registration += " ; /usr/bin/etcdctl set app/#{name.upcase}/#{name.upcase}_SERVICE_PORT #{min_port}"
        end

        {
          # A hack to be able to have two ExecStartPre values
          'EnvironmentFile'=>'/etc/environment',
          :ExecStartPre => "#{service_registration}",
          'ExecStartPre' => "-/usr/bin/docker pull #{source}",
          'ExecStart' => "-/bin/bash -c \"#{docker_run_string}\"",
          'ExecStartPost' => docker_rm,
          'ExecStop' => "-/bin/bash -c \"/usr/bin/etcdctl rm app/#{name.upcase} --recursive && /usr/bin/docker kill #{prefix}\"",
          'ExecStopPost' => docker_rm,
          'Restart' => 'always',
          'RestartSec' => '10',
          'TimeoutStartSec' => '5min'
        }
      end

      def fleet_block
        { 'Conflicts' => id.gsub(/@\d\./, "@*.") }
      end

      def docker_run_string
        [
          '/usr/bin/docker run',
          '--rm',
          "--name #{name.split('@').first}",
          port_flags,
          expose_flags,
          environment_flags,
          link_flags,
          volume_flags,
          source,
          command
        ].flatten.compact.join(' ').strip
      end

      def min_port
        if ports.empty?
          min_container_port = MAX_PORT
        else
          min_container_port = ports.sort_by { |port_binding| port_binding[:containerPort]}.first[:containerPort]
        end
        min_exposed = expose.sort.first || MAX_PORT
        min_port = [min_container_port.to_i, min_exposed.to_i].min
        min_port unless min_port == MAX_PORT
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

      def link_flags
        return unless links
        link_vars = []

        # add environment variables for linked services for etcd discovery
        links.each do |link|
          link_alias = link[:alias].upcase if link[:alias]
          link_name = link[:name].sanitize.upcase

          link_vars.push(
            {
              variable: (link_alias ? "#{link_alias}_SERVICE_HOST" : "#{link_name}_SERVICE_HOST").upcase,
              value: "`/usr/bin/etcdctl get app/#{link_name}/#{link_name}_SERVICE_HOST`"
            },
            {
              variable: (link_alias ? "#{link_alias}_SERVICE_PORT" : "#{link_name}_SERVICE_PORT").upcase,
              value: "`/usr/bin/etcdctl get app/#{link_name}/#{link_name}_SERVICE_PORT`"
            },
            {
              variable: (link_alias ? "#{link_alias}_PORT" : "#{link_name}_PORT").upcase,
              value: "#{link[:protocol]}://`/usr/bin/etcdctl get app/#{link_name}/#{link_name}_SERVICE_HOST`:`/usr/bin/etcdctl get app/#{link_name}/#{link_name}_SERVICE_PORT`"
            },
            {
              variable: (link_alias ? "#{link_alias}_PORT_#{link[:port]}_#{link[:protocol]}" : "#{link_name}_PORT_#{link[:port]}_#{link[:protocol]}").upcase,
              value: "#{link[:protocol]}://`/usr/bin/etcdctl get app/#{link_name}/#{link_name}_SERVICE_HOST`:`/usr/bin/etcdctl get app/#{link_name}/#{link_name}_SERVICE_PORT`"
            },
            {
              variable: (link_alias ? "#{link_alias}_PORT_#{link[:port]}_#{link[:protocol]}_PROTO" : "#{link_name}_PORT_#{link[:port]}_#{link[:protocol]}_PROTO").upcase,
              value: link[:protocol]
            },
            {
              variable: (link_alias ? "#{link_alias}_PORT_#{link[:port]}_#{link[:protocol]}_PORT" : "#{link_name}_PORT_#{link[:port]}_#{link[:protocol]}_PORT").upcase,
              value: "`/usr/bin/etcdctl get app/#{link_name}/#{link_name}_SERVICE_PORT`"
            },
            {
              variable: (link_alias ? "#{link_alias}_PORT_#{link[:port]}_#{link[:protocol]}_ADDR" : "#{link_name}_PORT_#{link[:port]}_#{link[:protocol]}_ADDR").upcase,
              value: "`/usr/bin/etcdctl get app/#{link_name}/#{link_name}_SERVICE_HOST`"
            }
          )
        end

        link_vars.map { |link| "-e #{link[:variable]}=#{link[:value]}" }
      end

      def environment_flags
        return unless environment
        environment.map { |env| "-e \'#{env[:variable]}=#{env[:value]}\'" }
      end

      def volume_flags
        return unless volumes
        volumes.map do |volume|
          option = '-v '
          option << "#{volume[:hostPath]}:" unless volume[:hostPath] == nil || volume[:hostPath] == ''
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
