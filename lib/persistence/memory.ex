defmodule Persistence.Memory do
  @moduledoc false

  use GenServer

  @behaviour Persistence.Store

  def start_link(options) do
    GenServer.start_link(__MODULE__, :ok, options)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def add(store, task) do
    GenServer.call(store, {:add, task})
  end

  def remove(store, id) do
    GenServer.call(store, {:remove, id})
  end

  def list(store) do
    GenServer.call(store, {:list})
  end

  def process_command(store, parameters) do
    GenServer.call(store, {:command, parameters})
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
