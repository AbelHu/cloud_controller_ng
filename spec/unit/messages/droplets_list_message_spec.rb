require 'spec_helper'
require 'messages/droplets_list_message'

module VCAP::CloudController
  describe DropletsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'states'    => 'state1,state2',
          'app_guids' => 'appguid1,appguid2',
          'page'      => 1,
          'per_page'  => 5,
          'order_by'  => 'created_at',
          'guids'     => 'guid1,guid2'
        }
      end

      it 'returns the correct DropletsListMessage' do
        message = DropletsListMessage.from_params(params)

        expect(message).to be_a(DropletsListMessage)
        expect(message.states).to eq(['state1', 'state2'])
        expect(message.app_guids).to eq(['appguid1', 'appguid2'])
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
        expect(message.guids).to match_array(['guid1', 'guid2'])
      end

      it 'converts requested keys to symbols' do
        message = DropletsListMessage.from_params(params)

        expect(message.requested?(:states)).to be_truthy
        expect(message.requested?(:app_guids)).to be_truthy
        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:order_by)).to be_truthy
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = DropletsListMessage.new({
          app_guids: [],
          states:    [],
          page:      1,
          per_page:  5,
          order_by:  'created_at',
          guids:     ['guid1', 'guid2']
        })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = DropletsListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = DropletsListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'validations' do
        describe 'validating app nested query' do
          context 'when the request contains both app_guid and app_guids' do
            it 'does not validate' do
              message = DropletsListMessage.new({ app_guid: 'blah', app_guids: ['app1', 'app2'] })
              expect(message).to_not be_valid
              expect(message.errors[:base]).to include("Unknown query parameter(s): 'app_guids'")
            end
          end
        end

        it 'validates app_guids is an array' do
          message = DropletsListMessage.new app_guids: 'tricked you, not an array'
          expect(message).to be_invalid
          expect(message.errors[:app_guids].length).to eq 1
        end

        it 'validates states is an array' do
          message = DropletsListMessage.new states: 'not array at all'
          expect(message).to be_invalid
          expect(message.errors[:states].length).to eq 1
        end
      end
    end

    describe '#to_param_hash' do
      it 'excludes app_guid' do
        expect(DropletsListMessage.new({ app_guid: '24234' }).to_param_hash.keys).to match_array([])
      end
    end
  end
end
