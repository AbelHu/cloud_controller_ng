require 'spec_helper'
require 'cloud_controller/blobstore/url_generator'
require 'cloud_controller/diego/buildpack/lifecycle_protocol'
require_relative '../lifecycle_protocol_shared'

module VCAP
  module CloudController
    module Diego
      module Buildpack
        RSpec.describe LifecycleProtocol do
          subject(:lifecycle_protocol) { LifecycleProtocol.new(blobstore_url_generator) }

          it_behaves_like 'a lifecycle protocol' do
            let(:app) { AppModel.make }
            let(:package) { PackageModel.make(app_guid: app.guid) }
            let(:droplet) { DropletModel.make(:staged, package_guid: package.guid, app_guid: app.guid) }
            let(:process) { App.make(app: app) }
            let(:staging_details) do
              Diego::StagingDetails.new.tap do |details|
                details.droplet   = droplet
                details.package   = package
                details.lifecycle = instance_double(BuildpackLifecycle, staging_stack: 'potato-stack', buildpack_info: buildpack_info)
              end
            end
            let(:blobstore_url_generator) do
              instance_double(::CloudController::Blobstore::UrlGenerator,
                buildpack_cache_download_url:            'cache-download-url',
                buildpack_cache_upload_url:              'cache-upload-url',
                package_download_url:                    'package-download-url',
                droplet_upload_url:                      'droplet-upload-url',
                unauthorized_perma_droplet_download_url: 'www.droplet.com'
              )
            end
            let(:buildpack_info) { BuildpackInfo.new('http://some-buildpack.url', nil) }

            before do
              app.update(droplet_guid: droplet.guid)
            end
          end

          before do
            VCAP::CloudController::Buildpack.create(name: 'ruby', key: 'ruby-buildpack-key', position: 2)
            allow(blobstore_url_generator).to receive(:admin_buildpack_download_url).and_return('bp-download-url')
          end

          describe '#lifecycle_data' do
            let(:app) { AppModel.make }
            let(:package) { PackageModel.make(app: app) }
            let(:droplet) { DropletModel.make(package: package, app: app) }

            let(:blobstore_url_generator) do
              instance_double(::CloudController::Blobstore::UrlGenerator,
                buildpack_cache_download_url: 'cache-download-url',
                buildpack_cache_upload_url:   'cache-upload-url',
                package_download_url:         'package-download-url',
                droplet_upload_url:           'droplet-upload-url'
              )
            end

            let(:buildpack) { nil }
            let(:buildpack_info) { BuildpackInfo.new(buildpack, VCAP::CloudController::Buildpack.find(name: buildpack)) }

            let(:staging_details) do
              Diego::StagingDetails.new.tap do |details|
                details.droplet               = droplet
                details.package               = package
                details.environment_variables = { 'nightshade_fruit' => 'potato' }
                details.staging_memory_in_mb  = 42
                details.staging_disk_in_mb    = 51
                details.lifecycle             = instance_double(BuildpackLifecycle, staging_stack: 'potato-stack', buildpack_info: buildpack_info)
              end
            end

            context 'when auto-detecting' do
              it 'sends buildpacks without skip_detect' do
                lifecycle_data = lifecycle_protocol.lifecycle_data(staging_details)

                expect(lifecycle_data[:buildpacks]).to have(1).items
                bp = lifecycle_data[:buildpacks][0]
                expect(bp).to include(name: 'ruby')
                expect(bp).to_not include(:skip_detect)
              end
            end

            context 'when a buildpack is requested' do
              let(:buildpack) { 'ruby' }

              it 'sends buildpacks with skip detect' do
                lifecycle_data = lifecycle_protocol.lifecycle_data(staging_details)

                expect(lifecycle_data[:buildpacks]).to have(1).items
                bp = lifecycle_data[:buildpacks][0]
                expect(bp).to include(name: 'ruby', skip_detect: true)
              end
            end

            context 'when a custom buildpack is requested' do
              let(:buildpack) { 'http://custom.com' }

              it 'sends buildpacks with skip detect' do
                lifecycle_data = lifecycle_protocol.lifecycle_data(staging_details)

                expect(lifecycle_data[:buildpacks]).to have(1).items
                bp = lifecycle_data[:buildpacks][0]
                expect(bp).to include(url: buildpack, skip_detect: true)
              end
            end

            context 'when the generated message has invalid data' do
              context 'when the package is missing a download uri (probably due to blobstore outages)' do
                before do
                  allow(blobstore_url_generator).to receive(:package_download_url).and_return(nil)
                end

                it 'raises an InvalidDownloadUri error' do
                  expect {
                    lifecycle_protocol.lifecycle_data(staging_details)
                  }.to raise_error LifecycleProtocol::InvalidDownloadUri, /Failed to get blobstore download url for package #{staging_details.package.guid}/
                end
              end

              context 'when the message is invalid for other reasons' do
                before do
                  allow(blobstore_url_generator).to receive(:droplet_upload_url).and_return(nil)
                end

                it 're-raises the error' do
                  expect {
                    lifecycle_protocol.lifecycle_data(staging_details)
                  }.to raise_error Membrane::SchemaValidationError, '{ droplet_upload_uri => Expected instance of String, given an instance of NilClass }'
                end
              end
            end
          end

          describe '#desired_app_message' do
            let(:blobstore_url_generator) do
              instance_double(
                ::CloudController::Blobstore::UrlGenerator,
                unauthorized_perma_droplet_download_url: 'www.droplet.com'
              )
            end

            let(:app) { AppModel.make }
            let(:package) { PackageModel.make(app_guid: app.guid) }
            let(:droplet) { DropletModel.make(:staged, package_guid: package.guid, app_guid: app.guid, droplet_hash: 'some_hash') }
            let(:process) { App.make(app: app, command: 'command from app', metadata: {}) }
            let(:staging_details) do
              Diego::StagingDetails.new.tap do |details|
                details.droplet   = droplet
                details.lifecycle = instance_double(BuildpackLifecycle, staging_stack: 'potato-stack', buildpack_info: buildpack_info)
              end
            end

            before do
              app.update(droplet_guid: droplet.guid)
            end

            it 'uses the process command' do
              start_command = lifecycle_protocol.desired_app_message(process)['start_command']
              expect(start_command).to eq('command from app')
            end

            it 'includes the droplet_uri' do
              droplet_uri = lifecycle_protocol.desired_app_message(process)['droplet_uri']

              expect(droplet_uri).to eq('www.droplet.com')
            end

            it 'includes the droplet_hash' do
              droplet_hash = lifecycle_protocol.desired_app_message(process)['droplet_hash']

              expect(droplet_hash).to eq('some_hash')
            end

            context 'when process does not have a start command set' do
              before do
                droplet.update(process_types: { other: 'command from droplet' })
                process.update(command: '', type: 'other')
              end

              it 'uses the droplet detected start command' do
                start_command = lifecycle_protocol.desired_app_message(process)['start_command']
                expect(start_command).to eq('command from droplet')
              end
            end
          end

          describe '#staging_action_builder' do
            let(:config) { { some: 'config' } }
            let(:package) { PackageModel.make }
            let(:droplet) { DropletModel.make }
            let(:staging_details) do
              StagingDetails.new.tap do |details|
                details.lifecycle = instance_double(BuildpackLifecycle, staging_stack: 'potato-stack', buildpack_info: 'some buildpack info')
                details.package = package
                details.droplet = droplet
              end
            end

            let(:blobstore_url_generator) do
              instance_double(
                ::CloudController::Blobstore::UrlGenerator,
                package_download_url: 'package_download_url',
                buildpack_cache_download_url: 'buildpack_cache_download_url',
                buildpack_cache_upload_url: 'buildpack_cache_upload_url',
                droplet_upload_url: 'droplet_upload_url'
              )
            end

            before do
              allow_any_instance_of(BuildpackEntryGenerator).to receive(:buildpack_entries).and_return(['buildpacks'])
            end

            it 'returns a StagingActionBuilder' do
              staging_action_builder = instance_double(StagingActionBuilder)
              allow(StagingActionBuilder).to receive(:new).and_return staging_action_builder

              expect(lifecycle_protocol.staging_action_builder(config, staging_details)).to be staging_action_builder

              expect(StagingActionBuilder).to have_received(:new).with(config, staging_details, hash_including({
                app_bits_download_uri: 'package_download_url',
                build_artifacts_cache_download_uri: 'buildpack_cache_download_url',
                buildpacks: ['buildpacks'],
                stack: 'potato-stack',
                build_artifacts_cache_upload_uri: 'buildpack_cache_upload_url',
                droplet_upload_uri: 'droplet_upload_url',
              }))
            end
          end

          describe '#task_action_builder' do
            let(:droplet_download_url) { 'www.droplet.com' }
            let(:blobstore_url_generator) do
              instance_double(
                ::CloudController::Blobstore::UrlGenerator,
                droplet_download_url: droplet_download_url
              )
            end
            let(:task) { TaskModel.make }
            let(:config) { { some: 'config' } }

            it 'returns a TaskActionBuilder' do
              task.app.update(buildpack_lifecycle_data: BuildpackLifecycleDataModel.make(stack: 'potato-stack'))

              task_action_builder = instance_double(TaskActionBuilder)
              allow(TaskActionBuilder).to receive(:new).and_return task_action_builder

              expect(lifecycle_protocol.task_action_builder(config, task)).to be task_action_builder

              expect(TaskActionBuilder).to have_received(:new).with(config, task, {
                droplet_uri: 'www.droplet.com',
                stack: 'potato-stack'
              })
            end

            context 'when the blobstore_url_generator returns nil' do
              let(:droplet_download_url) { nil }

              it 'returns an error' do
                expect {
                  lifecycle_protocol.task_action_builder(config, task)
                }.to raise_error(
                  VCAP::CloudController::Diego::Buildpack::LifecycleProtocol::InvalidDownloadUri,
                  /Failed to get blobstore download url for droplet #{task.droplet.guid}/
                )
              end
            end
          end
        end
      end
    end
  end
end
