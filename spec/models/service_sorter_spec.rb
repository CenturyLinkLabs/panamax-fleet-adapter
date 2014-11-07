require_relative '../spec_helper'

describe FleetAdapter::Models::ServiceSorter do

  describe '.sort' do
    let(:services) { hash_from_fixture('post-services.json') }
    subject(:sorted_services) { described_class.sort(services) }

    its(:count) { should eq 2 }

    it 'sorts services to start dependencies first' do
      expect(subject.first[:links]).to be_nil
      expect(subject.last[:links].count).to be 1
    end

    it 'sets the deployment count to 1 for dependencies' do
      expect(subject.first[:deployment][:count]).to eq 1 # was 3
    end

    it 'adds the port and protocol of the dependency to the dependent link hash' do
      expect(subject.last[:links].first[:name]).to eq 'DB'
      expect(subject.last[:links].first[:alias]).to eq 'DB_1'
      expect(subject.last[:links].first[:port]).to eq 3306
      expect(subject.last[:links].first[:protocol]).to eq 'tcp'
    end

    context 'when a dependent container exposes ports' do
      before do
        @db_service = services.find { |service| service[:name] == 'DB' }
        @db_service[:expose] = [80]
      end

      it 'uses the lowest numbered exposed port as the link port' do
        expect(subject.last[:links].first[:port]).to eq 80
      end

      it "uses 'tcp' as the link protocol" do
        expect(subject.last[:links].first[:protocol]).to eq 'tcp'
      end
    end

    context 'when a container links to itself' do
      let(:services) { hash_from_fixture('post-services.json') }

      before do
        @db_service = services.find { |service| service[:name] == 'DB' }
        @db_service[:links] = [{name: "DB", alias: "DB_1"}]
      end

      it 'raises an exception' do
        expect{ described_class.sort(services) }.to raise_error(ArgumentError, /image can not link to itself/)
      end

    end

    context 'when a container link links to a service that links back to it' do
      let(:services) { hash_from_fixture('post-services.json') }

      before do
        @db_service = services.find { |service| service[:name] == 'DB' }
        @db_service[:links] = [{name: "WP", alias: "wordpress"}]
      end

      it 'raises an exception' do
        expect{ described_class.sort(services) }.to raise_error(ArgumentError, /Circular import/)
      end

    end

    context 'when a dependency does not expose a port through expose or port bindings' do
      before do
        @db_service = services.find { |service| service[:name] == 'DB' }
        @db_service[:expose] = []
        @db_service[:ports] = []
      end

      it 'raises an exception' do
        expect{ described_class.sort(services) }.to raise_error(ArgumentError, /does not expose a port/)
      end
    end
  end

  describe '.get_service_names_for' do

    let(:links) do
      [
        {name: "FOO", alias: "BAR"},
        {name: "BAZ", alias: "QUUX"},
      ]
    end

    it 'returns an array of just the link names' do
      expect(described_class.send(:get_service_names_for, links)).to contain_exactly("FOO", "BAZ")
    end
  end

  describe '.ports_and_protocols_for' do
    it 'responds with mapped ports when there are only mapped ports' do
      service = { ports: [{ hostPort: 80, protocol: 'tcp' }] }
      expect(described_class.send(:ports_and_protocols_for, service)).to match_array([{ port: 80, protocol: 'tcp' }])
    end


    it 'responds with exposed ports when there are only exposed ports' do
      service = { expose: [80] }
      expect(described_class.send(:ports_and_protocols_for, service)).to match_array([{ port: 80, protocol: 'tcp' }])
    end

    it 'combines mapped and exposed ports if there are both' do
      service = { expose: [80], ports: [{ hostPort: 8080, protocol: 'tcp' }] }
      expect(described_class.send(:ports_and_protocols_for, service)).to match_array([{ port: 80, protocol: 'tcp' },
                                                                                      { port: 8080, protocol: 'tcp' }])
    end

    it 'returns an empty array if there no mapped or exposed ports' do
      service = { expose: [], ports: [] }
      expect(described_class.send(:ports_and_protocols_for, service)).to match_array([])
    end
  end
end
