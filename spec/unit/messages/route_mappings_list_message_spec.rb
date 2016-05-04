require 'spec_helper'
require 'messages/route_mappings_list_message'

module VCAP::CloudController
  describe RouteMappingsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
          'app_guid' => 'some_guid',
          'guids' => ['guid1', 'guid2']
        }
      end

      it 'returns the correct RouteMappingsListMessage' do
        message = RouteMappingsListMessage.from_params(params)

        expect(message).to be_a(RouteMappingsListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.app_guid).to eq('some_guid')
        expect(message.guids).to eq(['guid1', 'guid2'])
      end

      it 'converts requested keys to symbols' do
        message = RouteMappingsListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:app_guid)).to be_truthy
        expect(message.requested?(:guids)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          page:      1,
          per_page:  5,
        }
      end

      it 'excludes the pagination keys' do
        expected_params = []
        expect(RouteMappingsListMessage.new(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = RouteMappingsListMessage.new({
          page: 1,
          per_page: 5,
          app_guid: 'some-guid',
          guids: ['guid1', 'guid2']
        })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = RouteMappingsListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = RouteMappingsListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end

  describe 'validations' do

    context 'guids' do
      it 'validates guids is an array' do
        message = RouteMappingsListMessage.new({guids: 'I am not an array!'})
        expect(message).not_to be_valid
        expect(message.errors[:guids]).to include('must be an array')
      end

      it 'validates elements of array are guids' do
        message = RouteMappingsListMessage.new({guids: [0, ""]})
        expect(message).not_to be_valid
        expect(message.errors[:guids]).to include('must be a string')
        expect(message.errors[:guids]).to include('must be between 1 and 200 characters')
      end

      it 'accepts empty guids' do
        message = RouteMappingsListMessage.new({guids: nil})
        expect(message).to be_valid
      end
    end
  end

end
