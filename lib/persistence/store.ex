defmodule Persistence.Store do
  @callback add(Persistence.Store, Api.Task) :: :ok | {:error, String.t()}
  @callback remove(Persistence.Store, String.t()) :: :ok | {:error, String.t()}
  @callback list(Persistence.Store) :: File.Stream.t()
  @callback process_command(Persistence.Store, [String.t()]) :: :ok | {:error, String.t()}

  def add(store_type, store, task) do
    store_type.add(store, task)
  end

  def remove(store_type, store, id) do
    store_type.remove(store, id)
  end

  def list(store_type, store) do
    store_type.list(store)
  end

  def process_command(store_type, store, parameters) do
    store_type.process_command(store, parameters)
  end
end
