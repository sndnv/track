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

  def update_task(id, update) do
    case Api.Config.get(Config, :store) do
      {:ok, store} ->
        with {:ok, stream} <- Persistence.Store.list(store, Store) do
          target_task =
            stream
            |> flatten()
            |> Aggregate.Tasks.as_list()
            |> Enum.find(fn entry -> entry.id == id end)

          if target_task do
            case remove_task(target_task.id) do
              :ok ->
                updated_task =
                  update
                  |> Map.from_struct()
                  |> Enum.reduce(target_task, fn {field, value}, updated_task ->
                    if value do
                      Map.put(updated_task, field, value)
                    else
                      updated_task
                    end
                  end)

                add_task(updated_task)

              error ->
                error
            end
          else
            {:error, "Task with ID [#{id}] was not found"}
          end
        end

      :error ->
        message = "No store is configured"
        {:error, message}
    end
  end

  def start_task(task) do
    case Api.Config.get(Config, :store) do
      {:ok, store} ->
        with {:ok, stream} <- Persistence.Store.list(store, Store) do
          active_tasks =
            stream
            |> flatten()
            |> Aggregate.Tasks.with_no_duration()

          case active_tasks do
            [active_task | _] ->
              {:error, "Task [#{active_task.task} / #{active_task.id}] is already active"}

            [] ->
              task = %Api.Task{
                id: UUID.uuid4(),
                task: task,
                start: NaiveDateTime.utc_now(),
                duration: 0
              }

              add_task(task)
          end
        end

      :error ->
        message = "No store is configured"
        {:error, message}
    end
  end

  def stop_task() do
    case Api.Config.get(Config, :store) do
      {:ok, store} ->
        with {:ok, stream} <- Persistence.Store.list(store, Store) do
          active_tasks =
            stream
            |> flatten()
            |> Aggregate.Tasks.with_no_duration()

          case active_tasks do
            [active_task | _] ->
              case remove_task(active_task.id) do
                :ok ->
                  task_duration =
                    NaiveDateTime.diff(NaiveDateTime.utc_now(), active_task.start, :second)
                    |> div(60)

                  if task_duration > 0 do
                    updated_task = %{active_task | duration: task_duration}
                    add_task(updated_task)
                  else
                    :ok
                  end

                error ->
                  error
              end

            [] ->
              {:error, "No active tasks found"}
          end
        end

      :error ->
        message = "No store is configured"
        {:error, message}
    end
  end

  def list_tasks(query) do
    case Api.Config.get(Config, :store) do
      {:ok, store} ->
        with {:ok, stream} <- Persistence.Store.list(store, Store) do
          {
            :ok,
            stream
            |> flatten()
            |> with_query_filter(query)
            |> Aggregate.Tasks.as_sorted_list(query)
          }
        end

      :error ->
        message = "No store is configured"
        {:error, message}
    end
  end

  def get_duration_aggregation(query) do
    case Api.Config.get(Config, :store) do
      {:ok, store} ->
        with {:ok, stream} <- Persistence.Store.list(store, Store) do
          {
            :ok,
            stream
            |> flatten()
            |> with_query_filter(query)
            |> Aggregate.Tasks.with_total_duration(query)
          }
        end

      :error ->
        message = "No store is configured"
        {:error, message}
    end
  end

  def get_period_aggregation(query, period) do
    case Api.Config.get(Config, :store) do
      {:ok, store} ->
        with {:ok, stream} <- Persistence.Store.list(store, Store) do
          {
            :ok,
            stream
            |> flatten()
            |> with_query_filter(query)
            |> Aggregate.Tasks.per_period(query, period)
          }
        end

      :error ->
        message = "No store is configured"
        {:error, message}
    end
  end

  def get_task_aggregation(query, task_regex, group_period) do
    case Api.Config.get(Config, :store) do
      {:ok, store} ->
        with {:ok, stream} <- Persistence.Store.list(store, Store) do
          {
            :ok,
            stream
            |> flatten()
            |> with_query_filter(query)
            |> Aggregate.Tasks.per_period_for_a_task(query, task_regex, group_period)
          }
        end

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

  def flatten(stream) do
    stream
    |> Stream.flat_map(fn element ->
      case element do
        {:ok, entry} ->
          [entry]

        {:error, message} ->
          Logger.error(message)
          []
      end
    end)
  end

  def with_query_filter(stream, query) do
    from_unix = query.from |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
    to_unix = query.to |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

    stream
    |> Stream.filter(fn entry ->
      start_unix = entry.start |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
      from_unix <= start_unix && start_unix <= to_unix
    end)
  end
end
