defmodule Persistence.StoreTest do
  @moduledoc false

  use ExUnit.Case

  setup do
    start_supervised!({Persistence.Memory, name: Store})
    :ok
  end

  defp stream_to_list(stream) do
    stream
    |> Stream.map(fn {:ok, task} -> task end)
    |> Enum.to_list()
    |> Enum.sort_by(fn entry -> entry.task end)
  end

  test "passes requests to the specified store" do
    {:ok, start_time} = NaiveDateTime.from_iso8601("2018-12-21T01:02:03")

    expected_task_1 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task1",
      start: start_time,
      duration: 10
    }

    expected_task_2 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task2",
      start: start_time,
      duration: 20
    }

    expected_task_3 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: start_time,
      duration: 30
    }

    assert Persistence.Store.add(Persistence.Memory, Store, expected_task_1) == :ok
    assert Persistence.Store.add(Persistence.Memory, Store, expected_task_2) == :ok
    assert Persistence.Store.add(Persistence.Memory, Store, expected_task_3) == :ok
    {:ok, tasks_stream} = Persistence.Store.list(Persistence.Memory, Store)
    assert tasks_stream |> stream_to_list() == [expected_task_1, expected_task_2, expected_task_3]

    assert Persistence.Store.remove(Persistence.Memory, Store, expected_task_2.id) == :ok
    {:ok, tasks_stream} = Persistence.Store.list(Persistence.Memory, Store)
    assert tasks_stream |> stream_to_list() == [expected_task_1, expected_task_3]

    assert Persistence.Store.process_command(Persistence.Memory, Store, ["clear"]) == :ok
    {:ok, tasks_stream} = Persistence.Store.list(Persistence.Memory, Store)
    assert tasks_stream |> stream_to_list() == []
  end
end
