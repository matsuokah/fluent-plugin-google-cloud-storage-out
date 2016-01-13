require 'spec_helper'

describe Fluent::Plugin::Google::Cloud::Storage::Out do
  it 'has a version number' do
    expect(Fluent::Plugin::Google::Cloud::Storage::Out::VERSION).not_to be nil
  end

  it 'does something useful' do
    expect(false).to eq(true)
  end
end
