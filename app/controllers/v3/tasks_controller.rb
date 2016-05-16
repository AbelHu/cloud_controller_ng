require 'queries/app_fetcher'
require 'queries/task_list_fetcher'
require 'queries/task_create_fetcher'
require 'queries/task_fetcher'
require 'actions/task_create'
require 'actions/task_cancel'
require 'messages/task_create_message'
require 'messages/tasks_list_message'
require 'presenters/v3/task_presenter'
require 'controllers/v3/mixins/app_subresource'

class TasksController < ApplicationController
  include AppSubresource

  def index
    message = TasksListMessage.from_params(app_subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    if app_nested?
      app, dataset = TaskListFetcher.new.fetch_for_app(message: message)
      app_not_found! unless app && can_read?(app.space)
    else
      dataset = if roles.admin?
                  TaskListFetcher.new.fetch_all(message: message)
                else
                  TaskListFetcher.new.fetch_for_spaces(message: message, space_guids: readable_space_guids)
                end
    end

    render :ok, json: PaginatedListPresenter.new(dataset, base_url(resource: 'tasks'), message)
  end

  def create
    FeatureFlag.raise_unless_enabled!('task_creation') unless roles.admin?

    message = TaskCreateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app, space, _org, droplet = TaskCreateFetcher.new.fetch(app_guid: params[:app_guid], droplet_guid: message.droplet_guid)

    app_not_found! unless app && can_read?(space)
    unauthorized! unless can_write?(space)
    droplet_not_found! if message.requested?(:droplet_guid) && droplet.nil?

    task = TaskCreate.new(configuration).create(app, message, current_user.guid, current_user_email, droplet: droplet)

    render status: :accepted, json: TaskPresenter.new(task)
  rescue TaskCreate::InvalidTask, TaskCreate::TaskCreateError => e
    unprocessable!(e)
  end

  def cancel
    task, space, _org = TaskFetcher.new.fetch(task_guid: params[:task_guid])
    task_not_found! unless task && can_read?(space)

    unauthorized! unless can_write?(space)

    TaskCancel.new.cancel(task: task, user: current_user, email: current_user_email)

    render status: :accepted, json: TaskPresenter.new(task.reload)
  rescue TaskCancel::InvalidCancel => e
    unprocessable!(e)
  end

  def show
    task, space, _org = TaskFetcher.new.fetch(task_guid: params[:task_guid])
    task_not_found! unless task && can_read?(space)

    render status: :ok, json: TaskPresenter.new(task)
  end

  private

  def task_not_found!
    resource_not_found!(:task)
  end

  def droplet_not_found!
    resource_not_found!(:droplet)
  end
end
