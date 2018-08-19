defmodule Persistence.Store do
  @moduledoc """
  Behaviour spec for all task stores.
  """

  @doc """
  Adds a new task to the specified store.
  """

  @callback add(Persistence.Store, Api.Task) :: :ok | {:error, String.t()}

  @doc """
  Removes the task with the specified ID from the specified store.
  """

  @callback remove(Persistence.Store, String.t()) :: :ok | {:error, String.t()}

  @doc """
  Retrieves a stream of all task in the specified store.
  """

  @callback list(Persistence.Store) :: Stream

  @doc """
  Processes the specified command parameters.
  """

  @callback process_command(Persistence.Store, [String.t()]) :: :ok | {:error, String.t()}

  @doc """
  Adds a new task to the specified store.
  """

  def add(store_type, store, task) do
    store_type.add(store, task)
  end

  @doc """
  Removes the task with the specified ID from the specified store.
  """

  def remove(store_type, store, id) do
    store_type.remove(store, id)
  end

  @doc """
  Retrieves a stream of all task in the specified store.
  """

  def list(store_type, store) do
    store_type.list(store)
  end

  @doc """
  Processes the specified command parameters.
  """

  def process_command(store_type, store, parameters) do
    store_type.process_command(store, parameters)
  end
end
