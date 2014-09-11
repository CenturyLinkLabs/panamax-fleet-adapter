require 'sinatra'
require 'fleet'
require "sinatra/reloader" if development?

#set :port, ENV['PORT']
set :bind, '0.0.0.0'

class Service

  attr_accessor :name, :description, :source, :links, :command, :ports, 
    :expose, :environment, :volumes

  def self.find(unit_name)
    new('name' => unit_name)
  end

  def initialize(attrs)
    self.name = attrs["name"]
    self.description = attrs["description"]
    self.source = attrs["source"]
    self.links = attrs["links"]
    self.command= attrs["command"]
    self.ports = attrs["ports"]
    self.expose = attrs["expose"]
    self.environment = attrs["environment"]
    self.volumes = attrs["volumes"]
  end

  def load
    fleet.load(service_name, service_def, async=true)
  end

  def start
    fleet.start(service_name)
  end

  def stop
    fleet.stop(service_name, async=true)
  end

  def status
    fleet.status(service_name)
  end

  def destroy
    fleet.destroy(service_name, async=true)
  end

  def service_name
    name.end_with?(".service") ? name : "#{name}.service"
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
      source,
      command
    ].flatten.compact.join(' ').strip
  end

  def service_def
    unit_block = {
      'Description' => description
    }

    if links
      dep_services = links.map do |link|
        "#{link['name']}".service
      end.join(' ')

      unit_block['After'] = dep_services
      unit_block['Requires'] = dep_services
    end

    docker_rm = "-/usr/bin/docker rm #{name}"
    service_block = {
      'ExecStartPre' => "-/usr/bin/docker pull #{source}",
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

  def fleet
    @fleet ||= Fleet.new(fleet_api_url: 'http://10.1.42.1:4001')
  end
end

before do
  headers 'Content-Type' => 'application/json'
end

get '/services' do
  fleet = Fleet.new(fleet_api_url: 'http://10.1.42.1:4001')
  fleet.list_units.to_json
end

get '/services/:id' do
  Service.find(params[:id]).status.to_json
end

post '/services' do
  request.body.rewind
  body = JSON.parse(request.body.read)

  services = body['services'].map do |service|
    Service.new(service).tap(&:load)
  end.each(&:start)

  services.map(&:service_name).to_json
end

put '/services/:id' do
  request.body.rewind
  body = JSON.parse(request.body.read)
  puts body
  service = Service.find(params[:id])

  if body['desired_state'] == 'started'
    service.start
    204
  elsif body['desired_state'] == 'stopped'
    service.stop
    204
  else
    400
  end
end

delete '/services/:id' do
  begin
    Service.find(params[:id]).destroy
  rescue
  end
  204
end

