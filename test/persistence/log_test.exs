defmodule Persistence.LogTest do
  @moduledoc false

  use ExUnit.Case

  @log_file_path "run/#{UUID.uuid4()}_test.log"

  setup do
    start_supervised!({
      Persistence.Log,
      name: Store, store_options: %{log_file_path: @log_file_path}
    })

    :ok
  end

  defp task_query_fn() do
    File.stream!(@log_file_path)
    |> Stream.map(&String.replace(&1, "\n", ""))
    |> Stream.map(fn raw_entry -> Poison.decode!(raw_entry, as: %Api.Task{}) end)
    |> Stream.map(fn entry ->
      {:ok, start} = NaiveDateTime.from_iso8601(entry.start)
      %{entry | start: start}
    end)
    |> Enum.to_list()
  end

  test "adds tasks to the log" do
    assert Persistence.StoreBehaviour.adds_tasks(
             Persistence.Log,
             Store,
             &task_query_fn/0
           ) == :ok

    assert File.rm!(@log_file_path) == :ok
  end

  test "removes tasks from the log" do
    assert Persistence.StoreBehaviour.removes_tasks(
             Persistence.Log,
             Store,
             &task_query_fn/0
           ) == :ok

    assert File.rm!(@log_file_path) == :ok
  end

  test "lists tasks in the log" do
    assert Persistence.StoreBehaviour.lists_tasks(Persistence.Log, Store) == :ok
    assert File.rm!(@log_file_path) == :ok
  end

  test "process commands" do
    assert Persistence.StoreBehaviour.processes_commands(Persistence.Log, Store) == :ok
    assert File.rm!(@log_file_path) == :ok
  end
end
