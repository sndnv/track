defmodule Api.Service do
  @moduledoc """
  Service that handles all data access and changes.

  Expected options:
  - `:api_options`
    - `:store` - task store type
    - `:store_options` - settings to use when initializing the store
  """

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

  @doc """
  Adds the supplied task to the data store.
  """

  def add_task(task) do
    {:ok, store} = Api.Config.get(Config, :store)
    Persistence.Store.add(store, Store, task)
  end

  @doc """
  Removes the task with the specified ID.
  """

  def remove_task(id) do
    {:ok, store} = Api.Config.get(Config, :store)
    Persistence.Store.remove(store, Store, id)
  end

  @doc """
  Applies the supplied update to the task with the specified ID.

  The existing task is removed and re-added with the updates applied.
  """

  def update_task(id, update) do
    {:ok, store} = Api.Config.get(Config, :store)

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
  end

  @doc """
  Starts a new active task with the specified task name.

  Only one active task is allowed; to stop an existing active task,
  a call to `Api.Service.stop_task/0` is required.
  """

  def start_task(task) do
    {:ok, store} = Api.Config.get(Config, :store)

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
  end

  @doc """
  Stops an existing active task and records the final duration.

  If the task's calculated duration is under one minute, the task is discarded.
  """

  def stop_task() do
    {:ok, store} = Api.Config.get(Config, :store)

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
  end

  @doc """
  Retrieves a list of all tasks and applies the supplied query to the result.
  """

  def list_tasks(query) do
    {:ok, store} = Api.Config.get(Config, :store)

    with {:ok, stream} <- Persistence.Store.list(store, Store) do
      {
        :ok,
        stream
        |> flatten()
        |> with_query_filter(query)
        |> Aggregate.Tasks.as_sorted_list(query)
      }
    end
  end

  @doc """
  Retrieves a list of all tasks that overlap, grouped by day.
  """

  def list_overlapping_tasks() do
    {:ok, store} = Api.Config.get(Config, :store)

    with {:ok, stream} <- Persistence.Store.list(store, Store) do
      {
        :ok,
        stream
        |> flatten()
        |> Aggregate.Tasks.with_overlapping_periods()
      }
    end
  end

  @doc """
  Retrieves all tasks that match the supplied query, grouped by task with their total duration.
  """

  def get_duration_aggregation(query) do
    {:ok, store} = Api.Config.get(Config, :store)

    with {:ok, stream} <- Persistence.Store.list(store, Store) do
      {
        :ok,
        stream
        |> flatten()
        |> with_query_filter(query)
        |> Aggregate.Tasks.with_total_duration(query)
      }
    end
  end

  @doc """
  Retrieves all tasks that match the supplied query, grouped by the specified period.

  The supported periods are: `:day`, `:week`, `:month`.
  """

  def get_period_aggregation(query, period) do
    {:ok, store} = Api.Config.get(Config, :store)

    with {:ok, stream} <- Persistence.Store.list(store, Store) do
      {
        :ok,
        stream
        |> flatten()
        |> with_query_filter(query)
        |> Aggregate.Tasks.per_period(query, period)
      }
    end
  end

  @doc """
  Retrieves all tasks that match the supplied query and regular expression, grouped by the specified period.

  The supported periods are: `:day`, `:week`, `:month`.
  """

  def get_task_aggregation(query, task_regex, group_period) do
    {:ok, store} = Api.Config.get(Config, :store)

    with {:ok, stream} <- Persistence.Store.list(store, Store) do
      {
        :ok,
        stream
        |> flatten()
        |> with_query_filter(query)
        |> Aggregate.Tasks.per_period_for_a_task(query, task_regex, group_period)
      }
    end
  end

  @doc """
  Forwards the supplied command parameters to the specified service.
  """

  def process_command(service, parameters) do
    case service do
      "store" ->
        {:ok, store} = Api.Config.get(Config, :store)
        Persistence.Store.process_command(store, Store, parameters)

      _ ->
        {:error, "Service [#{service}] not found"}
    end
  end

  @doc """
  Extracts all tasks from the supplied stream and logs all errors.
  """

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

  @doc """
  Filters the supplied stream based on the query' from/to timestamps.
  """

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
