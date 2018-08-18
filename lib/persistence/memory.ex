defmodule Persistence.Memory do
  @moduledoc false

  use GenServer
  require Logger

  @behaviour Persistence.Store

  def start_link(options) do
    GenServer.start_link(__MODULE__, :ok, options)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def add(store, task) do
    Logger.debug(fn -> "[memory] [add] Adding task [#{inspect(task)}] to log" end)

    result = GenServer.call(store, {:add, task})

    Logger.debug(fn ->
      "[memory] [add] Task addition for [#{task.id}] completed with: [#{inspect(result)}]"
    end)

    result
  end

  def remove(store, id) do
    Logger.debug(fn -> "[memory] [remove] Removing task [#{id}] from log" end)

    result = GenServer.call(store, {:remove, id})

    Logger.debug(fn ->
      "[memory] [remove] Task removal for [#{id}] completed with: [#{inspect(result)}]"
    end)

    result
  end

  def list(store) do
    Logger.debug(fn -> "[memory] [list] Retrieving tasks stream" end)

    result = GenServer.call(store, {:list})

    Logger.debug(fn -> "[memory] [list] Tasks stream retrieved: [#{inspect(result)}]" end)

    result
  end

  def process_command(store, parameters) do
    Logger.debug(fn ->
      "[memory] [command] Executing command with parameters: [#{inspect(parameters)}]"
    end)

    result = GenServer.call(store, {:command, parameters})

    Logger.debug(fn ->
      "[memory] [command] Command execution completed with: [#{inspect(result)}]"
    end)

    result
  end

  def handle_call(request, _from, store) do
    case request do
      {:add, task} ->
        {:reply, :ok, Map.put(store, task.id, task)}

      {:remove, id} ->
        {:reply, :ok, Map.delete(store, id)}

      {:list} ->
        stream = store |> Stream.map(fn {_, v} -> {:ok, v} end)
        {:reply, {:ok, stream}, store}

      {:command, parameters} ->
        result =
          case parameters do
            ["clear" | _] ->
              {:ok, %{}}

            [command | _] ->
              {:error, "Command [#{command}] is not supported"}

            [] ->
              {:error, "No command specified"}
          end

        case result do
          {:ok, updated_store} -> {:reply, :ok, updated_store}
          error -> {:reply, error, store}
        end
    end
  end
end
