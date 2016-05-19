require 'cloud_controller/blobstore/client'
require 'cloud_controller/blobstore/fog/fog_client'
require 'cloud_controller/blobstore/fog/error_handling_client'
require 'cloud_controller/blobstore/webdav/dav_client'
require 'cloud_controller/blobstore/bits_service/bits_service_client'
require 'cloud_controller/blobstore/safe_delete_client'

module CloudController
  module Blobstore
    class ClientProvider
      def self.provide(options:, directory_key:, root_dir: nil, resource_type: '', bits_client: nil)
        return Client.new(BitsServiceClient.new(bits_client: bits_client, resource_type: resource_type)) if bits_client

        if options[:blobstore_type].blank? || (options[:blobstore_type] == 'fog')
          provide_fog(options, directory_key, root_dir)
        else
          provide_webdav(options, directory_key, root_dir)
        end
      end

      class << self
        private

        def provide_fog(options, directory_key, root_dir)
          cdn_uri = options[:cdn].try(:[], :uri)
          cdn     = CloudController::Blobstore::Cdn.make(cdn_uri)

          client = FogClient.new(
            options.fetch(:fog_connection),
            directory_key,
            cdn,
            root_dir,
            options[:minimum_size],
            options[:maximum_size]
          )

          Client.new(ErrorHandlingClient.new(SafeDeleteClient.new(client, root_dir)))
        end

        def provide_webdav(options, directory_key, root_dir)
          client = DavClient.build(
            options.fetch(:webdav_config),
            directory_key,
            root_dir,
            options[:minimum_size],
            options[:maximum_size]
          )

          Client.new(SafeDeleteClient.new(client, root_dir))
        end
      end
    end
  end
end
