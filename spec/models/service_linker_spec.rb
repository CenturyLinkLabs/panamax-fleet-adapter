require 'spec_helper'

describe FleetAdapter::Models::ServiceLinker do

  let(:service_1) { Service.new(name: '1', links: [{ name: '2' }]) }
  let(:service_2) do
    Service.new(name: '2', ports: [{ containerPort: '1111' }], deployment: { count: 3 })
  end
  let(:services) { [service_1, service_2] }

  it 'sets references to linked services' do
    described_class.link(services)
    expect(service_1.links.first[:service]).to eq service_2
  end

  it 'sets the deployment count to 1 for child services' do
    described_class.link(services)
    expect(service_2.deployment_count).to eq 1
  end

  context 'when the child service is not linkable' do

    before do
      service_2.ports.clear
    end

    it 'raises an ArgumentError' do
      expect { described_class.link(services) }.to raise_error(
        ArgumentError, /does not have an explicit port/)
    end
  end
end
