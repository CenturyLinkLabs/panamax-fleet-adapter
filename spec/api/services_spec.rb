require_relative '../spec_helper'

describe FleetAdapter::Routes::Services do

  let(:id) { 'foo@1.service' }

  describe 'POST /services' do

    let(:service_name) { 'myservice' }

    let(:request_body) do
      [
          { name: service_name, source: 'foo/bar' }
      ].to_json
    end

    before do
      allow_any_instance_of(ServiceMediator)
          .to receive(:load_and_start_all)
          .and_return([Service.new(name: service_name, source: 'foo/bar')])
    end

    it 'loads and starts the services via the mediator' do
      expect_any_instance_of(ServiceMediator).to receive(:load_and_start_all).exactly(:once)
      post '/v1/services', request_body
    end

    it 'returns an array of service IDs' do
      expected = [{ id: "#{service_name}.service" }].to_json

      post '/v1/services', request_body
      expect(last_response.body).to eq expected
    end

    it 'has an application/json Content-Type' do
      post '/v1/services', request_body
      expect(last_response.headers['Content-Type']).to eq 'application/json'
    end

    it 'returns a 201 status' do
      post '/v1/services', request_body
      expect(last_response.status).to eq 201
    end

    context 'when a dependency has no exposed ports' do
      let(:request_body) do
        [
            { name: 'service', source: 'foo/bar', links: [{ name: 'dependency' }] },
            { name: 'dependency', source: 'bar/foo' }
        ].to_json
      end

      before do
        allow_any_instance_of(ServiceMediator)
            .to receive(:load_and_start_all)
            .and_raise(ArgumentError, 'dependency does not have an explicit port binding')
      end

      it 'returns a 422 status' do
        post '/v1/services', request_body
        expect(last_response.status).to eq 422
      end

      it 'includes an error message indicating the service should expose a port' do
        expected = { error: 'dependency does not have an explicit port binding' }.to_json
        post '/v1/services', request_body
        expect(last_response.body).to eq expected
      end
    end
  end

  describe 'GET /services/:id' do

    let(:status) { 'load_state: loaded; active_state: active; sub_state: running' }

    before do
      allow_any_instance_of(ServiceMediator).to receive(:status_for).with(id).and_return(status)
    end

    it 'returns the status formatted as JSON' do
      expected = { id: id, actualState: status }.to_json

      get "/v1/services/#{id}"
      expect(last_response.body).to eq expected
    end

    it 'has an application/json Content-Type' do
      get "/v1/services/#{id}"
      expect(last_response.headers['Content-Type']).to eq 'application/json'
    end

    it 'returns a 200 status' do
      get "/v1/services/#{id}"
      expect(last_response.status).to eq 200
    end

    context 'when the service cannot be found' do

      before do
        allow_any_instance_of(ServiceMediator).to receive(:status_for).and_raise(Fleet::NotFound.new('Key not found'))
      end

      it 'returns a 404 status' do
        get "/v1/services/#{id}"
        expect(last_response.status).to eq 404
      end
    end

  end

  describe 'PUT /services/:id' do

    context "when attempting to start" do
      let(:request_body) do
          { desiredState: 'started' }.to_json
      end

      before do
        allow_any_instance_of(ServiceMediator).to receive(:start).with(id).and_return(true)
      end

      it 'returns a 204 status' do
        put "/v1/services/#{id}", request_body
        expect(last_response.status).to eq 204
      end
    end

    context "when attempting to stop" do
      let(:request_body) do
        { desiredState: 'stopped' }.to_json
      end

      before do
        allow_any_instance_of(ServiceMediator).to receive(:stop).with(id).and_return(true)
      end

      it 'returns a 204 status' do
        put "/v1/services/#{id}", request_body
        expect(last_response.status).to eq 204
      end
    end

    context "when sending some other desired state" do
      let(:request_body) do
        { desiredState: 'thrashing wildly' }.to_json
      end

      it 'returns a 400 status' do
        put "/v1/services/#{id}", request_body
        expect(last_response.status).to eq 400
      end
    end
  end

  describe 'DELETE /services/:id' do

    before do
      allow_any_instance_of(ServiceMediator).to receive(:destroy).with(id).and_return(true)
    end

    it 'finds the service with the given id' do
      expect_any_instance_of(ServiceMediator).to receive(:destroy).with(id)
      delete "/v1/services/#{id}"
    end

    it 'destroys the service' do
      expect_any_instance_of(ServiceMediator).to receive(:destroy).with(id)
      delete "/v1/services/#{id}"
    end

    it 'returns a 204 status' do
      delete "/v1/services/#{id}"
      expect(last_response.status).to eq 204
    end
  end

end

