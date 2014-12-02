require_relative '../spec_helper'
require_relative '../../app/utils'

describe FleetAdapter::Models::ServiceConverter do
  using FleetAdapter::StringExtensions

  let(:service_attrs) { hash_from_fixture('post-services.json') }

  let(:dependency) do
    Service.new(service_attrs[1]).tap do |s|
      s.dependency = true
    end
  end

  let(:service) do
    Service.new(service_attrs[0]).tap do |s|
      s.name = 'WP@1'
      s.dependencies << dependency
    end.clone
  end

  subject { described_class.new(service) }

  describe '#service_def' do
    context 'when the service has links' do
      it 'assigns dependencies to the unit_block' do
        expect(subject.send(:service_def)['Unit']['After']).to eq('db.service')
        expect(subject.send(:service_def)['Unit']['Wants']).to eq('db.service')
      end
    end

    context 'when the service has no links' do
      before do
        subject.instance_variable_get(:@service).links = []
      end
      it 'does not assign dependencies to the unit_block' do
        expect(subject.send(:service_def)['Unit']['After']).to be_nil
        expect(subject.send(:service_def)['Unit']['Wants']).to be_nil
      end
    end

    it 'creates a docker rm string command with the service name only' do
      expect(subject.send(:service_def)['Service']['ExecStartPost']).to eq('-/usr/bin/docker rm WP')
      expect(subject.send(:service_def)['Service']['ExecStopPost']).to eq('-/usr/bin/docker rm WP')
    end

    it 'creates a docker kill string command with the service name only' do
      expect(subject.send(:service_def)['Service']['ExecStop'])
        .to eq('-/bin/bash -c "/usr/bin/etcdctl rm app/WP@1 --recursive && /usr/bin/docker kill WP"')
    end

    it 'adds an X-Fleet block to the unit file' do
      expect(subject.send(:service_def).keys).to include 'X-Fleet'
    end

    context 'when the service is scaled' do
      it 'adds a wildcard Conflicts rule to the X-Fleet block' do
        expect(subject.send(:service_def)['X-Fleet']['Conflicts']).to eq('WP@*.service')
      end
    end

    context 'when the service is not scaled' do
      before do
        service.name = 'WP'
      end

      it 'adds a non-wildcard Conflicts rule to the X-Fleet block' do
        expect(subject.send(:service_def)['X-Fleet']['Conflicts']).to eq('WP.service')
      end
    end
  end

  describe '#docker_run_string' do
    context 'when the service specifies exposed ports' do

      before do
        subject.instance_variable_get(:@service).expose = [3306]
      end

      it 'generates a docker command with --expose' do
        expect(subject.send(:docker_run_string)).to include '--expose 3306'
      end
    end

    context 'when the service specifies port mappings' do
      before do
        service.ports = [{ hostInterface: '0.0.0.0', hostPort: '8000', containerPort: '3000' }]
      end

      it 'generates a docker command with -p' do
        expect(subject.send(:docker_run_string)).to include '-p 0.0.0.0:8000:3000'
      end

      context 'when the hostPort is empty' do

        before do
          service.ports = [{ hostInterface: nil, hostPort: '', containerPort: '3000' }]
        end

        it 'does not include the colon affixed to the host port info' do
          expect(subject.send(:docker_run_string)).to include '-p 3000'
        end
      end

      context 'when the UDP protocol is specified' do

        before do
          service.ports = [{ containerPort: '3306', protocol: 'udp' }]
        end

        it 'generates a docker command with -p with the udp protocol' do
          expect(subject.send(:docker_run_string)).to include '-p 3306/udp'
        end
      end

      context 'when the TCP protocol is specified' do

        before do
          service.ports = [{ containerPort: '3306', protocol: 'tcp' }]
        end

        it 'generates a docker command with -p with no protocol' do
          expect(subject.send(:docker_run_string)).to include '-p 3306'
        end
      end
    end

    context 'when the service specifies environment vars' do
      it 'generates a docker command with -e' do
        expect(subject.send(:docker_run_string)).to include "-e 'DB_PASSWORD=pass@word01'"
      end
    end

    context 'when the service specifies docker links' do
      it 'translates docker links to environment variables' do
        expect(subject.send(:docker_run_string))
          .to include '-e DB_1_SERVICE_HOST=`/usr/bin/etcdctl get app/DB/DB_SERVICE_HOST`'
        expect(subject.send(:docker_run_string))
          .to include '-e DB_1_PORT=tcp://`/usr/bin/etcdctl get app/DB/DB_SERVICE_HOST`:1111'
        expect(subject.send(:docker_run_string)).to include '-e DB_1_PORT_3306_TCP_PROTO=tcp'
        expect(subject.send(:docker_run_string))
          .to include '-e DB_1_PORT_3306_TCP_ADDR=`/usr/bin/etcdctl get app/DB/DB_SERVICE_HOST`'
        expect(subject.send(:docker_run_string))
          .to include '-e DB_1_PORT_3306_TCP=tcp://`/usr/bin/etcdctl get app/DB/DB_SERVICE_HOST`:1111'
        expect(subject.send(:docker_run_string)).to include '-e DB_1_PORT_3306_TCP_PORT=1111'
      end

      it 'sanitizes the link names when creating the env vars' do
        service.links = [
          {
            name: 'db_@:.-',
            alias: 'db_1',
            exposed_ports: [{ protocol: 'tcp', containerPort: 3306, hostPort: 3306 }]
          }
        ]
        expect(subject.send(:docker_run_string))
          .to include '-e DB_1_SERVICE_HOST=`/usr/bin/etcdctl get app/DB-----/DB-----_SERVICE_HOST`'
      end
    end

    context 'when the service specifies volumes' do
      before do
        service.volumes = [{ hostPath: '/foo/bar', containerPath: '/bar/baz' }]
      end

      it 'generates a docker command with -v' do
        expect(subject.send(:docker_run_string)).to include '-v /foo/bar:/bar/baz'
      end

      it 'excludes the : if only a container volume is specified' do
        subject.volumes.first[:hostPath] = ''
        expect(subject.send(:docker_run_string)).to include '-v /bar/baz'
      end
    end
  end
end
