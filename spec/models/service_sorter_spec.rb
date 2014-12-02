require_relative '../spec_helper'

describe FleetAdapter::Models::ServiceSorter do

  let(:services) do
    services_attrs = hash_from_fixture('post-services.json')
    services_attrs.map do |service_attrs|
      Service.new(service_attrs)
    end.flatten
  end

  describe '.sort' do

    subject(:sorted_services) { described_class.sort(services) }

    its(:count) { should eq 2 }

    it 'sorts services to start dependencies first' do
      expect(subject.first.links).to be_empty
      expect(subject.last.links.count).to be 1
    end

    it "adds services to a dependent service's collection of dependencies" do
      expect(subject.last.dependencies.count).to be 1
    end

    context 'when a container links to itself' do
      before do
        @db_service = services.find { |service| service.name == 'db' }
        @db_service.links = [{ name: 'DB', alias: 'DB_1' }]
      end

      it 'raises an exception' do
        expect{ described_class.sort(services) }.to raise_error(ArgumentError, /image can not link to itself/)
      end

    end

    context 'when a container link links to a service that links back to it' do
      before do
        @db_service = services.find { |service| service.name == 'db' }
        @db_service.links = [{ name: 'WP', alias: 'wordpress' }]
      end

      it 'raises an exception' do
        expect{ described_class.sort(services) }.to raise_error(ArgumentError, /Circular import/)
      end

    end
  end

  describe '.get_service_names_for' do

    let(:links) do
      [
        { name: 'FOO', alias: 'BAR' },
        { name: 'BAZ', alias: 'QUUX' },
      ]
    end

    it 'returns an array of just the link names' do
      expect(described_class.send(:get_service_names_for, links)).to contain_exactly('foo', 'baz')
    end
  end
end
