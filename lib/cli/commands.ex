defmodule Cli.Commands do
  @moduledoc """
  Handlers for all commands supported by the application.

  For each command, the user's input is parsed, the command is executed and (if available) the output is returned.
  """

  @doc """
  Adds a new task.
  """

  def add_task(args) do
    with {:ok, task} <- Cli.Parse.args_to_task(args) do
      Api.Service.add_task(task)
    end
  end

  @doc """
  Removes an existing task.
  """

  def remove_task(args) do
    case args do
      [id | _] ->
        case UUID.info(id) do
          {:ok, _} -> Api.Service.remove_task(id)
          {:error, _} -> {:error, "[#{id}] is not a valid task ID"}
        end

      [] ->
        {:error, "Task ID is required"}
    end
  end

  @doc """
  Updates an existing task.
  """

  def update_task(args) do
    case args do
      [id | args] ->
        case UUID.info(id) do
          {:ok, _} ->
            with {:ok, update} <- Cli.Parse.args_to_task_update(args) do
              Api.Service.update_task(id, update)
            end

          {:error, _} ->
            {:error, "[#{id}] is not a valid task ID"}
        end

      [] ->
        {:error, "Task ID is required"}
    end
  end

  @doc """
  Starts a new active task.
  """

  def start_task(args) do
    case args do
      [task | _] -> Api.Service.start_task(task)
      [] -> {:error, "Task is required"}
    end
  end

  @doc """
  Stops an existing active task.
  """

  def stop_task() do
    Api.Service.stop_task()
  end

  @doc """
  Lists all tasks, based on the parsed query data (if available).
  """

  def list(args) do
    with {:ok, query} <- Cli.Parse.args_to_query(args),
         {:ok, list} <- Api.Service.list_tasks(query),
         {:ok, table} <- Cli.Render.tasks_table(list) do
      {:output, table}
    end
  end

  @doc """
  Generates a report, based on the requested report type and parsed query data (if available).

  The supported reports are:
  - `duration` - total task duration (bar chart)
  - `day` - daily task distribution (bar chart)
  - `week` - weekly task distribution (bar chart)
  - `month` - monthly task distribution (bar chart)
  - `task` - daily task duration (line chart)
  - `overlap` - overlapping tasks per day (table)
  """

  def report(args) do
    case args do
      ["duration" | args] ->
        with {:ok, query} <- Cli.Parse.args_to_query(args),
             {:ok, list} <- Api.Service.get_duration_aggregation(query),
             {:ok, chart} <- Cli.Render.duration_aggregation_as_bar_chart(list, query) do
          {:output, chart}
        end

      [period | args] when period == "day" or period == "week" or period == "month" ->
        period = String.to_atom(period)

        with {:ok, query} <- Cli.Parse.args_to_query(args),
             {:ok, list} <- Api.Service.get_period_aggregation(query, period),
             {:ok, chart} <- Cli.Render.period_aggregation_as_bar_chart(list, query, period) do
          {:output, chart}
        end

      ["task" | args] ->
        case args do
          [task_regex | args] ->
            with {:ok, task_regex} <- Regex.compile(task_regex),
                 {:ok, query} <- Cli.Parse.args_to_query(args),
                 {:ok, list} <- Api.Service.get_task_aggregation(query, task_regex, :day),
                 {:ok, chart} <-
                   Cli.Render.task_aggregation_as_line_chart(
                     list,
                     query,
                     task_regex,
                     :day
                   ) do
              {:output, chart}
            end

          [] ->
            {:error, "Task name or regular expression is required"}
        end

      ["overlap" | _] ->
        with {:ok, list} <- Api.Service.list_overlapping_tasks(),
             {:ok, table} <- Cli.Render.overlapping_tasks_table(list) do
          {:output, table}
        end

      [report | _] ->
        {:error, "[#{report}] report not supported"}

      [] ->
        {:error, "No report specified"}
    end
  end

  @doc """
  Forwards a command to the requested service.
  """

  def service(args) do
    case args do
      [service | parameters] ->
        case parameters do
          [_ | _] -> Api.Service.process_command(service, parameters)
          [] -> {:error, "No service parameters specified"}
        end

      [] ->
        {:error, "Service name is required"}
    end
  end

  @doc """
  Builds a colour legend showing a brief description of what the various chart/table colours mean.
  """

  def legend() do
    {:output, Cli.Render.period_colour_legend()}
  end
end
