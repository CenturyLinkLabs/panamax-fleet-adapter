require 'spec_helper'

describe FleetAdapter::Routes::Healthcheck do

  describe 'GET /healthcheck' do

    before do
      allow_any_instance_of(Fleet::Client).to receive(:list_machines)
    end

    it 'has a text/plain Content-Type' do
      get '/healthcheck'
      expect(last_response.headers['Content-Type']).to eq 'text/plain'
    end

    it 'returns a 200 status' do
      get '/healthcheck'
      expect(last_response.status).to eq 200
    end

    context 'when Fleet is healthy' do
      it 'returns true' do
        get '/healthcheck'
        expect(last_response.body).to eq 'true'
      end
    end

    context 'when Fleet is NOT healthy' do

      before do
        allow_any_instance_of(Fleet::Client).to receive(:list_machines)
          .and_raise('oops')
      end

      it 'returns false' do
        get '/healthcheck'
        expect(last_response.body).to eq 'false'
      end
    end
  end
end
