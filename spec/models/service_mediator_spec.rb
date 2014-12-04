require_relative '../spec_helper'
require_relative '../../app/utils'

describe FleetAdapter::Models::ServiceMediator do

  let(:fake_fleet_client) do
    double(:fake_fleet_client,
           load: true,
           start: true,
           stop: true,
           destroy: true,
           status: {}
    )
  end

  subject { ServiceMediator.new(hash_from_fixture('post-services.json')) }

  before do
    allow(Fleet).to receive(:new) { fake_fleet_client }
  end

  describe '#initialize' do
    it 'defines and initializes the service_attrs attribute' do
      expect(subject.instance_variable_defined?(:@services_attrs)).to be true
      expect(subject.instance_variable_get(:@services_attrs)).to be_an Array
    end

    it 'defines and initializes the services attribute' do
      expect(subject.instance_variable_defined?(:@services)).to be true
      expect(subject.instance_variable_get(:@services)).to be_an Array
      expect(subject.instance_variable_get(:@services)).to be_empty

    end
  end

  describe '#service_prototypes' do
    it 'creates the list of service prototypes' do
      result = subject.send(:service_prototypes)
      expect(result).to be_an Array
      expect(result.map(&:name)).to match_array(['db', 'wp'])
    end
  end

  describe '#load_and_start_all' do
    before { subject.load_and_start_all }

    it 'populates the list of services scaled by deployment count' do
      expect(subject.instance_variable_get(:@services).map(&:name)).to match_array(['db', 'wp@1', 'wp@2', 'wp@3'])
    end
  end

  describe '#load_service' do
    let(:service) { double(:service, id: 'any.service') }

    before do
      allow_any_instance_of(ServiceConverter).to receive(:service_def).and_return({})
    end

    it 'sends the id and service_def to the fleet client' do
      expect(fake_fleet_client).to receive(:load).with(service.id, {})
      subject.send(:load_service, service)
    end
  end

  describe '#status_for' do
    context 'when the specified service exists' do
      before do
        allow(fake_fleet_client).to receive(:status).and_return(active_state: 'active',
                                                                load_state: 'loaded',
                                                                sub_state: 'running',
                                                                machine_state: 'wtf')
      end

      it 'returns the status of a unit' do
        expect(subject.status_for('any.service')).to match /load_state: loaded/
        expect(subject.status_for('any.service')).to match /active_state: active/
        expect(subject.status_for('any.service')).to match /sub_state: running/
        expect(subject.status_for('any.service')).not_to match /machine_state/
      end
    end

    context 'when the specified service does not exist' do
      before do
        allow(fake_fleet_client).to receive(:status).and_return nil
      end
      it "returns 'error' as the state" do
        expect(subject.status_for('any.service')).to eq 'error'
      end
    end
  end

  [:start, :stop, :destroy].each do |method|
    describe "##{method}" do
      it "sends a #{method} message to the fleet client" do
        expect(fake_fleet_client).to receive(method).with('foo.service')
        subject.send(method, 'foo.service')
      end

      it 'returns the result of the fleet call' do
        expect(subject.send(method, 'foo.service')).to eql true
      end
    end
  end

end
