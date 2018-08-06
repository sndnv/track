defmodule Api.Service do
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, options)
  end

  def init(options) do
    store = options[:api_options][:store]
    store_options = options[:api_options][:store_options]

    children = [
      {Api.Config, name: Config, api_options: options[:api_options]},
      {
        store,
        name: Store, store_options: store_options
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def add_task(task) do
    case Api.Config.get(Config, :store) do
      {:ok, store} ->
        Persistence.Store.add(store, Store, task)

      :error ->
        message = "No store is configured"
        {:error, message}
    end
  end

  def remove_task(id) do
    case Api.Config.get(Config, :store) do
      {:ok, store} ->
        Persistence.Store.remove(store, Store, id)

      :error ->
        message = "No store is configured"
        {:error, message}
    end
  end

  def list_tasks() do
    case Api.Config.get(Config, :store) do
      {:ok, store} ->
        Persistence.Store.list(store, Store)

      :error ->
        message = "No store is configured"
        {:error, message}
    end
  end

  def process_command(service, parameters) do
    case service do
      "store" ->
        case Api.Config.get(Config, :store) do
          {:ok, store} ->
            Persistence.Store.process_command(store, Store, parameters)

          :error ->
            message = "No store is configured"
            {:error, message}
        end

      _ ->
        {:error, "Service [#{service}] not found"}
    end
  end
end
