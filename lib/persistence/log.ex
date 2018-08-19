defmodule Persistence.Log do
  @moduledoc """
  File-based task store.

  Supported commands:
  - `clear` - removes all tasks

  Expected options:
  - `:store_options`
    - `:log_file_path` - store file path
  """

  use GenServer
  require Logger

  @behaviour Persistence.Store

  def start_link(options) do
    GenServer.start_link(
      __MODULE__,
      [
        log_file_path: options[:store_options][:log_file_path]
      ],
      options
    )
  end

  def init(options) do
    {
      :ok,
      [
        File.stream!(options[:log_file_path], [:append, :utf8]),
        options
      ]
    }
  end

  def add(store, task) do
    Logger.debug(fn -> "[log] [add] Adding task [#{inspect(task)}] to log" end)

    result = GenServer.call(store, {:add, task})

    Logger.debug(fn ->
      "[log] [add] Task addition for [#{task.id}] completed with: [#{inspect(result)}]"
    end)

    result
  end

  def remove(store, id) do
    Logger.debug(fn -> "[log] [remove] Removing task [#{id}] from log" end)

    result = GenServer.call(store, {:remove, id})

    Logger.debug(fn ->
      "[log] [remove] Task removal for [#{id}] completed with: [#{inspect(result)}]"
    end)

    result
  end

  def list(store) do
    Logger.debug(fn -> "[log] [list] Retrieving tasks stream" end)

    result = GenServer.call(store, {:list})

    Logger.debug(fn -> "[log] [list] Tasks stream retrieved: [#{inspect(result)}]" end)

    result
  end

  def process_command(store, parameters) do
    Logger.debug(fn ->
      "[log] [command] Executing command with parameters: [#{inspect(parameters)}]"
    end)

    result = GenServer.call(store, {:command, parameters})

    Logger.debug(fn ->
      "[log] [command] Command execution completed with: [#{inspect(result)}]"
    end)

    result
  end

  def handle_call(request, _from, state) do
    [log_file, options] = state

    case request do
      {:add, task} ->
        result =
          case Poison.encode(task) do
            {:ok, encoded} ->
              [encoded]
              |> Stream.map(&"#{&1}\n")
              |> Stream.into(log_file)
              |> Stream.run()

              :ok

            {:error, error} ->
              message = "Failed to write task [#{inspect(task)}] to log: [#{error}]"
              {:error, message}
          end

        {:reply, result, state}

      {:remove, id} ->
        temp_file_name = "#{options[:log_file_path]}-#{UUID.uuid4()}.temp"
        temp_file = File.stream!(temp_file_name, [:append, :utf8])

        log_file
        |> Stream.reject(fn line -> String.contains?(line, id) end)
        |> Stream.into(temp_file)
        |> Stream.run()

        result = File.rename(temp_file_name, options[:log_file_path])

        {:reply, result, state}

      {:list} ->
        stream =
          log_file
          |> Stream.map(&String.replace(&1, "\n", ""))
          |> Stream.map(fn raw_entry ->
            case Poison.decode(raw_entry, as: %Api.Task{}) do
              {:ok, entry} ->
                case NaiveDateTime.from_iso8601(entry.start) do
                  {:ok, start} ->
                    {:ok, %{entry | start: start}}

                  {:error, error} ->
                    message =
                      "Unexpected response received while parsing entry timestamp: [#{error}]"

                    {:error, message}
                end

              {:error, error} ->
                message = "Failed to decode entry: [#{raw_entry}]: [#{error}]"
                {:error, message}
            end
          end)

        {:reply, {:ok, stream}, state}

      {:command, parameters} ->
        result =
          case parameters do
            ["clear" | _] ->
              case File.rm(options[:log_file_path]) do
                :ok ->
                  case File.touch(options[:log_file_path]) do
                    :ok ->
                      :ok

                    {:error, error} ->
                      {:error,
                       "Failed to recreate log file [#{options[:log_file_path]}]: [#{error}]"}
                  end

                {:error, error} ->
                  {:error, "Failed to remove log file [#{options[:log_file_path]}]: [#{error}]"}
              end

            [command | _] ->
              {:error, "Command [#{command}] is not supported"}

            [] ->
              {:error, "No command specified"}
          end

        {:reply, result, state}
    end
  end
end
