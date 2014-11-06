require 'spec_helper'

describe FleetAdapter::StringExtensions do

  using described_class

  it 'adds a #sanitize method to strings' do
    expect { String.new.sanitize }.to_not raise_error
  end

  describe '#sanitize' do

    subject { 'FOO-1_1.2@3' }

    it 'properly sanitizes the string for Fleet' do
      expect(subject.sanitize).to eq 'foo-1-1-2-3'
    end
  end
end
