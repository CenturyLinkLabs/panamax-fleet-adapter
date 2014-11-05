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
      allow_any_instance_of(Service).to receive(:load)
      allow_any_instance_of(Service).to receive(:start)
    end

    it 'loads the services' do
      expect_any_instance_of(Service).to receive(:load).exactly(:once)
      post '/v1/services', request_body
    end

    it 'starts the services' do
      expect_any_instance_of(Service).to receive(:start).exactly(:once)
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

      it 'returns a 422 status' do
        post '/v1/services', request_body
        expect(last_response.status).to eq 422
      end

      it 'includes an error message indicating the service should expose a port' do
        expected = { error: 'dependency does not expose a port' }.to_json
        post '/v1/services', request_body
        expect(last_response.body).to eq expected
      end
    end
  end

  describe 'GET /services/:id' do

    let(:model) { Service.new(id: id) }
    let(:status) { 'started' }

    before do
      allow(Service).to receive(:find).and_return(model)
      allow(model).to receive(:status).and_return(status)
    end

    it 'returns the status formatted as JSON' do
      expected = { id: model.id, actualState: model.status }.to_json

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
        allow(Service).to receive(:find).and_raise(Fleet::NotFound.new('Key not found'))
      end

      it 'returns a 404 status' do
        get "/v1/services/#{id}"
        expect(last_response.status).to eq 404
      end
    end

  end

  describe 'PUT /services/:id' do

    let(:model) { Service.new(id: id) }

    before do
      allow(Service).to receive(:find).and_return(model)
    end

    context "when attempting to start" do
      let(:request_body) do
          { desiredState: 'started' }.to_json
      end

      before do
        allow(model).to receive(:start).and_return(true)
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
        allow(model).to receive(:stop).and_return(true)
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

      before do
        allow(model).to receive(:stop).and_return(true)
      end

      it 'returns a 400 status' do
        put "/v1/services/#{id}", request_body
        expect(last_response.status).to eq 400
      end
    end
  end

  describe 'DELETE /services/:id' do

    let(:model) { Service.new(id: id) }

    before do
      allow(Service).to receive(:find).and_return(model)
      allow(model).to receive(:destroy)
    end

    it 'finds the service with the given id' do
      expect(Service).to receive(:find).with(id)
      delete "/v1/services/#{id}"
    end

    it 'destroys the service' do
      expect(model).to receive(:destroy)
      delete "/v1/services/#{id}"
    end

    it 'returns a 204 status' do
      delete "/v1/services/#{id}"
      expect(last_response.status).to eq 204
    end
  end

end

