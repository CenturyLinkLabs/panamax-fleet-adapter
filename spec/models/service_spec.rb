require_relative '../spec_helper'
require_relative '../../app/utils'

describe FleetAdapter::Models::Service do
  using FleetAdapter::StringExtensions

  let(:attrs) do
    {
      name: 'foo',
      source: 'bar',
      command: '/bin/bash',
      ports: [{ hostPort: 80, containerPort: 80 }],
      expose: [80],
      environment: [{ variable: 'DB_PASSWORD', value: 'password' }],
      volumes: [{ hostPath: '/foo/bar', containerPath: '/bar/baz' }],
      links: [{ name: 'db', alias: 'db_1' }],
      deployment: { count: 10 }
    }
  end

  subject { described_class.new(attrs) }

  describe '#initialize' do

    context 'when no attrs are specified' do
      subject { described_class.new({}) }

      its(:name) { is_expected.to be_empty }
      its(:source) { is_expected.to be_nil }
      its(:links) { is_expected.to eq [] }
      its(:command) { is_expected.to be_nil }
      its(:ports) { is_expected.to eq [] }
      its(:expose) { is_expected.to eq [] }
      its(:environment) { is_expected.to eq [] }
      its(:volumes) { is_expected.to eq [] }
      its(:deployment) { is_expected.to eq(count: 1) }
    end

    context 'when attrs are specified' do
      its(:id) { is_expected.to eq 'foo.service' }
      its(:name) { is_expected.to eq attrs[:name] }
      its(:source) { is_expected.to eq attrs[:source] }
      its(:links) { is_expected.to eq attrs[:links] }
      its(:command) { is_expected.to eq attrs[:command] }
      its(:ports) { is_expected.to eq attrs[:ports] }
      its(:expose) { is_expected.to eq [80] }
      its(:environment) { is_expected.to eq attrs[:environment] }
      its(:volumes) { is_expected.to eq attrs[:volumes] }
      its(:deployment) { is_expected.to eq attrs[:deployment] }
    end

    context 'when the name has a space' do
      subject { described_class.new(name: 'foo bar', deployment: { count: 1 }) }
      it 'replaces spaces with underscores' do
        expect(subject.name).to eq('foo-bar')
      end
    end

  end

  describe '#id' do
    context 'when there is no id' do
      it 'sets the id to name.service' do
        expect(subject.id).to eq("#{subject.name}.service")
      end
    end

    context 'when the service was created with an id' do
      subject { described_class.new(id: 'foobar.service', name: 'foo bar') }
      it 'returns the id' do
        expect(subject.id).to eq('foobar.service')
      end
    end
  end

  describe '#prefix' do
    context 'when the name does not contain the @ character' do
      it 'returns the name' do
        expect(subject.prefix).to eq 'foo'
      end
    end

    context 'when the name contains the @ character' do
      subject { described_class.new({}).tap { |s| s.name = 'foo@1' } }
      it 'returns the portion before the @ character' do
        expect(subject.prefix).to eq 'foo'
      end
    end
  end

  describe '#is_dependency?' do
    subject { described_class.new({}).tap { |s| s.dependency = true } }
    it 'returns true when the service is a dependency' do
      expect(subject.dependency?).to be true
    end
  end

  describe '#dependencies' do
    it 'returns an array' do
      expect(subject.dependencies).to be_an Array
    end
  end

  describe '#deployment_count' do
    it 'returns an int' do
      expect(subject.deployment_count).to be_an Integer
    end

    context 'when no deployment is provided' do
      subject { described_class.new({}) }
      it 'returns a count of 1' do
        expect(subject.deployment_count).to be 1
      end
    end

    context 'when a deployment is provided' do
      it 'returns the count' do
        expect(subject.deployment_count).to be attrs[:deployment][:count]
      end
    end
  end

  describe '#clone' do
    let(:dependency) do
      Service.new(
        name: 'db',
        ports: [{ hostPort: 3306, containerPort: 3306 }],
        expose: [3306]
      )
    end

    subject { described_class.new(attrs).tap { |s| s.dependencies << dependency } }

    it 'clones the prototype' do
      expect(subject.clone).to be_a described_class
    end

    it "adds the dependency's exposed ports to links" do
      expect(subject.clone.links[0]).to have_key(:exposed_ports)
    end

    it 'adds the port and protocol of the dependency to the dependent link hash' do
      expect(subject.clone.links.first[:name]).to eq 'db'
      expect(subject.clone.links.first[:alias]).to eq 'db_1'
      expect(subject.clone.links.first[:exposed_ports].first[:hostPort]).to eq 3306
      expect(subject.clone.links.first[:exposed_ports].first[:containerPort]).to eq 3306
      expect(subject.clone.links.first[:exposed_ports].first[:protocol]).to eq 'tcp'
    end
  end

  describe '#set_link_port_and_protocol' do
    let(:dependency) do
      Service.new(name: 'db')
    end

    subject { described_class.new(attrs).tap { |s| s.dependencies << dependency } }

    it 'raises an exception if there are no ports' do
      expect { subject.send(:set_link_port_and_protocol, dependency) }
        .to raise_error(ArgumentError, /does not have an explicit port binding/)
    end
  end
end
