require 'spec_helper'
describe 'tacacsplus' do

  context 'with defaults for all parameters' do
    it { should contain_class('tacacsplus') }
  end
end
