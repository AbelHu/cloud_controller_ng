require 'cloud_controller/diego/lifecycles/app_buildpack_lifecycle'
require 'cloud_controller/diego/lifecycles/app_docker_lifecycle'
require 'cloud_controller/diego/lifecycles/lifecycles'

class AppLifecycleProvider
  TYPE_TO_LIFECYCLE_CLASS_MAP = {
    Lifecycles::BUILDPACK => AppBuildpackLifecycle,
    Lifecycles::DOCKER    => AppDockerLifecycle
  }.freeze
  DEFAULT_LIFECYCLE_TYPE = Lifecycles::BUILDPACK

  def self.provide_for_create(message)
    provide(message, nil)
  end

  def self.provide_for_update(message, app)
    provide(message, app)
  end

  def self.provide(message, app)
    type = if message.requested?(:lifecycle)
             message.lifecycle_type
           elsif !app.nil?
             app.lifecycle_type
           else
             DEFAULT_LIFECYCLE_TYPE
           end

    TYPE_TO_LIFECYCLE_CLASS_MAP[type].new(message)
  end
  private_class_method :provide
end
