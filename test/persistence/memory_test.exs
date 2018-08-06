defmodule Persistence.MemoryTest do
  @moduledoc false

  use ExUnit.Case

  setup do
    start_supervised!({Persistence.Memory, name: Store})
    :ok
  end

  defp task_query_fn() do
    {:ok, stream} = Persistence.Memory.list(Store)

    stream
    |> Stream.map(fn {:ok, entry} -> entry end)
    |> Enum.to_list()
    |> Enum.sort_by(fn entry -> entry.task end)
  end

  test "adds tasks to the store" do
    assert Persistence.StoreBehaviour.adds_tasks(
             Persistence.Memory,
             Store,
             &task_query_fn/0
           ) == :ok
  end

  test "removes tasks from the store" do
    assert Persistence.StoreBehaviour.removes_tasks(
             Persistence.Memory,
             Store,
             &task_query_fn/0
           ) == :ok
  end

  test "lists tasks in the store" do
    assert Persistence.StoreBehaviour.lists_tasks(Persistence.Memory, Store) == :ok
  end

  test "process commands" do
    assert Persistence.StoreBehaviour.processes_commands(Persistence.Memory, Store) == :ok
  end
end
