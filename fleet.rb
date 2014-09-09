require 'sinatra'
require 'fleet'

#set :port, ENV['PORT']
set :bind, '0.0.0.0'

class Service

  attr_accessor :name, :description, :source, :links, :command, :ports, 
    :expose, :environment, :volumes

  def initialize(attrs)
    self.name = attrs[:name]
    self.description = attrs[:description]
    self.source = attrs[:source]
    self.links = attrs[:links]
    self.command= atrrs[:command]
    self.ports = attrs[:ports]
    self.expose = attrs[:expose]
    self.environment = attrs[:environment]
    self.volumes = attrs[:volumes]
  end

  def docker_run_string
    [
      '/usr/bin/docker run',
      '--rm',
      "--name #{name}",
      link_flags,
      port_flags,
      expose_flags,
      environment_flags,
      volume_flags,
      from,
      command
    ].flatten.compact.join(' ').strip
  end

  def service_def
    unit_block = {
      'Description' => description
    }

    if links.any?
      dep_services = links.map do |link|
        "#{link['name']}".service
      end.join(' ')

      unit_block['After'] = dep_services
      unit_block['Requires'] = dep_services
    end

    docker_rm = "-/usr/bin/docker rm #{name}"
    service_block = {
      'ExecStartPre' => "-/usr/bin/docker pull #{from}",
      'ExecStart' => docker_run_string,
      'ExecStartPost' => docker_rm,
      'ExecStop' => "-/usr/bin/docker kill #{name}",
      'ExecStopPost' => docker_rm,
      'Restart' => 'always',
      'RestartSec' => '10',
      'TimeoutStartSec' => '5min'
    }

    {
      'Unit' => unit_block,
      'Service' => service_block
    }
  end

  private

  def link_flags
    return unless links
    links.map do |link|
      option = '--link '
      option << link['name']
      option << ':'
      option << (link['alias'] ? link['alias'] : link['name'])
      option
    end
  end

  def port_flags
    return unless ports
    ports.map do |port|
      option = '-p '
      if port['host_interface'] || port['host_port']
        option << "#{port['host_interface']}:" if port['host_interface']
        option << "#{port['host_port']}" if port['host_port']
        option << ':'
      end
      option << "#{port['container_port']}"
      option << '/udp' if port['proto'] && port['proto'].upcase == 'UDP'
      option
    end
  end

  def expose_flags
    return unless expose
    expose.map { |exposed_port| "--expose #{exposed_port}" }
  end

  def environment_flags
    return unless environment
    environment.map { |env| "-e \"#{env['variable']}=#{env['value']}\"" }
  end

  def volume_flags
    return unless volumes
    volumes.map do |volume|
      option = '-v '
      option << "#{volume['host_path']}:" if volume['host_path'].present?
      option << volume['container_path']
      option
    end
  end

end

before do
  headers 'Content-Type' => 'application/json'
end

get '/apps' do
  fleet = Fleet.new(fleet_api_url: 'http://localhost:4001')
  fleet.list_units.to_json
end

post '/apps' do
  request.body.rewind
  puts JSON.parse request.body.read
end
