defmodule Api.Service do
  @moduledoc false

  use Supervisor
  require Logger

  # TODO - get from config
  @store Persistence.Log
  @log_file_path "run/tasks.log"

  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, options)
  end

  def init(options) do
    children = [
      {@store, name: Store, log_file_path: @log_file_path}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def add_task(task) do
    Persistence.Store.add(@store, Store, task)
  end

  def remove_task(id) do
    Persistence.Store.remove(@store, Store, id)
  end

  def list_tasks() do
    Persistence.Store.list(@store, Store)
  end

  def process_command(service, parameters) do
    case service do
      "store" -> Persistence.Store.process_command(@store, Store, parameters)
      _ -> {:error, "Service [#{service}] not found"}
    end
  end
end
