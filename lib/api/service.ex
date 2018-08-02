defmodule Api.Service do
  @moduledoc false

  use GenServer
  require Logger

  def start_link(options) do
    GenServer.start_link(__MODULE__, :ok, options)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def add(service, task) do
    GenServer.call(service, {:add, task})
  end

  def update(service, task) do
    GenServer.call(service, {:update, task})
  end

  def delete(service, task) do
    GenServer.call(service, {:delete, task})
  end

  def list(service) do
    GenServer.call(service, {:list})
  end

  def handle_call(request, _from, store) do
    case request do
      {:add, task} -> {:reply, :todo, store} # TODO
      {:update, task} -> {:reply, :todo, store} # TODO
      {:delete, task} -> {:reply, :todo, store} # TODO
      {:list} -> {:reply, :todo, store} # TODO
    end
  end
end
