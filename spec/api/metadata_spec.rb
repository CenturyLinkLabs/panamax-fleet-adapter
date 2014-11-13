require_relative '../spec_helper'

describe 'Metadata Endpoint' do
  describe 'GET /v1/metadata' do
    let(:response) { get '/v1/metadata' }
    subject(:hash) { JSON.parse(response.body) }
    before { stub_const("FleetAdapter::VERSION", "2.0") }

    it "has a 200 response code" do
      expect(response.status).to eq(200)
    end

    it "has a JSON Content-Type" do
      expect(response.headers["Content-Type"]).to eq("application/json")
    end

    its(:keys) { should eq([ "version", "type" ]) }
    its(["version"]) { should eq("2.0") }
    its(["type"]) { should eq("Fleet") }
  end
end
