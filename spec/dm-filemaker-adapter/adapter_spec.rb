require 'spec_helper'

describe DataMapper::Adapters::FilemakerAdapter do
  it 'has a version number' do
    expect(DataMapper::Adapters::FilemakerAdapter::VERSION).not_to be nil
  end

  it 'does something useful' do
    expect(true).to eq(true)
  end
  
  describe '#create' do
  	it 'calls rfm layout with appropriate params'
  end
end
