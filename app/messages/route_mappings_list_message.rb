require 'messages/list_message'

module VCAP::CloudController
  class RouteMappingsListMessage < ListMessage
    ALLOWED_KEYS = [:page, :per_page, :app_guid, :guids].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator

    validates :guids, array: true, allow_nil: true

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def to_param_hash
      super(exclude: [:page, :per_page, :order_by])
    end

    def self.from_params(params)
      opts = params.dup
      new(opts.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
