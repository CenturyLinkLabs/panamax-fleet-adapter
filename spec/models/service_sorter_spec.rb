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
        expect{ described_class.sort(services) }.to raise_error(RuntimeError, /image can not link to itself/)
      end

    end

    context 'when a container link links to a service that links back to it' do
      let(:services) { hash_from_fixture('post-services.json') }

      before do
        @db_service = services.find { |service| service[:name] == 'DB' }
        @db_service[:links] = [{name: "WP", alias: "wordpress"}]
      end

      it 'raises an exception' do
        expect{ described_class.sort(services) }.to raise_error(RuntimeError, /Circular import/)
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
end
