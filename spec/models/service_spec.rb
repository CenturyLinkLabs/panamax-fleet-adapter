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

  describe '#deployment_count=' do
    it 'sets the deployment count' do
      subject.deployment_count = 2
      expect(subject.deployment_count).to eq 2
    end
  end

  describe '#linkable?' do

    context 'when the service is linkable' do
      before do
        subject.ports = [{ containerPort: '123' }]
      end

      it 'returns true' do
        expect(subject.linkable?).to eq true
      end
    end

    context 'when the service is not linkable' do
      before do
        subject.ports = nil
      end

      it 'returns false' do
        expect(subject.linkable?).to eq false
      end
    end
  end

end
