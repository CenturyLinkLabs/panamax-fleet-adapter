require_relative '../spec_helper'

describe FleetAdapter::Models::ServiceSorter do

  let(:service_1) { Service.new(name: '1') }
  let(:service_2) { Service.new(name: '2') }
  let(:service_3) { Service.new(name: '3') }
  let(:services)  { [service_1, service_2, service_3] }

  before do
    service_1.links << { service: service_2 }
    service_2.links << { service: service_3 }
  end

  describe '.sort' do

    subject(:sorted_services) { described_class.sort(services) }

    its(:count) { should eq 3 }

    it 'sorts services to start dependencies first' do
      expect(subject).to match_array([service_3, service_2, service_1])
    end

    context 'when a container links to itself' do

      before do
        service_1.links << { service: service_1 }
      end

      it 'raises an exception' do
        expect{ described_class.sort(services) }.to raise_error(
          ArgumentError, /circular reference/)
      end

    end

    context 'when a container link links to a service that links back to it' do

      before do
        service_3.links << { service: service_1 }
      end

      it 'raises an exception' do
        expect{ described_class.sort(services) }.to raise_error(
          ArgumentError, /circular reference/)
      end

    end
  end
end
