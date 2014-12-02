module FleetAdapter
  module Models
    class ServiceConverter
      extend Forwardable

      using FleetAdapter::StringExtensions

      def_delegators :@service, :id, :name, :prefix, :source, :links, :command, :ports, :expose, :environment, :volumes,
                     :deployment

      def initialize(service)
        @service = service
      end

      def service_def
        {
          'Unit' => unit_block,
          'Service' => service_block,
          'X-Fleet' => fleet_block
        }
      end

      private

      def unit_block
        unit_block = {}

        unless links.empty?
          dependencies = links.map do |link|
            "#{link[:name].sanitize}.service"
          end.join(' ')

          unit_block['After'] = dependencies
          unit_block['Wants'] = dependencies
        end

        unit_block
      end

      def service_block
        docker_rm = "-/usr/bin/docker rm #{prefix}"
        etcd_dir = "app/#{name.upcase}"
        etcd_key = "#{etcd_dir}/#{name.upcase}_SERVICE_HOST"
        service_registration = "/usr/bin/etcdctl set #{etcd_key} ${COREOS_PRIVATE_IPV4}"

        {
          'EnvironmentFile' => '/etc/environment',
          'ExecStartPre' => ["#{service_registration}", "-/usr/bin/docker pull #{source}"],
          'ExecStart' => "-/bin/bash -c \"#{docker_run_string}\"",
          'ExecStartPost' => docker_rm,
          'ExecStop' => "-/bin/bash -c \"/usr/bin/etcdctl rm #{etcd_dir} --recursive && /usr/bin/docker kill #{prefix}\"",
          'ExecStopPost' => docker_rm,
          'Restart' => 'always',
          'RestartSec' => '10',
          'TimeoutStartSec' => '5min'
        }
      end

      def fleet_block
        { 'Conflicts' => id.gsub(/@\d\./, '@*.') }
      end

      def docker_run_string
        [
          '/usr/bin/docker run',
          '--rm',
          "--name #{prefix}",
          port_flags,
          expose_flags,
          environment_flags,
          link_flags,
          volume_flags,
          source,
          command
        ].flatten.compact.join(' ').strip
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
          link_name = link[:name].sanitize.upcase
          link_alias = link[:alias] ? link[:alias].upcase : link_name
          etcd_key = "app/#{link_name}/#{link_name}_SERVICE_HOST"
          min_port = link[:exposed_ports].sort_by { |exposed_port| exposed_port[:containerPort] }.first

          link_vars.push(
            {
              variable: "#{link_alias}_SERVICE_HOST",
              value: "`/usr/bin/etcdctl get #{etcd_key}`"
            },
            {
              variable: "#{link_alias}_PORT",
              value: "#{min_port[:protocol]}://`/usr/bin/etcdctl get #{etcd_key}`:#{min_port[:hostPort]}"
            }
          )

          # Docker-esque container linking variables
          link[:exposed_ports].each do |exposed_port|
            container_port = exposed_port[:containerPort]
            host_port = exposed_port[:hostPort]
            protocol = exposed_port[:protocol]
            alias_var_base = "#{link_alias}_PORT_#{container_port}_#{protocol}".upcase

            link_vars.push(
              {
                variable: alias_var_base,
                value: "#{protocol}://`/usr/bin/etcdctl get #{etcd_key}`:#{host_port}"
              },
              {
                variable: "#{alias_var_base}_PROTO",
                value: protocol
              },
              {
                variable: "#{alias_var_base}_PORT",
                value: host_port
              },
              {
                variable: "#{alias_var_base}_ADDR",
                value: "`/usr/bin/etcdctl get #{etcd_key}`"
              }
            )
          end
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
          option << "#{volume[:hostPath]}:" unless volume[:hostPath].nil? || volume[:hostPath] == ''
          option << volume[:containerPath]
          option
        end
      end
    end
  end
end
