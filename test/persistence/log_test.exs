defmodule Persistence.LogTest do
  @moduledoc false

  use ExUnit.Case
  require Logger

  @log_file_path "run/#{UUID.uuid4()}_test.log"

  setup do
    start_supervised!({Persistence.Log, name: Store, log_file_path: @log_file_path})
    :ok
  end

  test "adds tasks to the log" do
    {:ok, start_time, 0} = DateTime.from_iso8601("2018-12-21T01:02:03Z")

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

    assert Persistence.Log.add(Store, expected_task_1) == :ok
    assert Persistence.Log.add(Store, expected_task_2) == :ok
    assert Persistence.Log.add(Store, expected_task_3) == :ok

    tasks =
      File.stream!(@log_file_path)
      |> Stream.map(&String.replace(&1, "\n", ""))
      |> Stream.map(fn raw_entry -> Poison.decode!(raw_entry, as: %Api.Task{}) end)
      |> Stream.map(fn entry ->
        {:ok, start, 0} = DateTime.from_iso8601(entry.start)
        %{entry | start: start}
      end)
      |> Enum.to_list()

    assert tasks == [expected_task_1, expected_task_2, expected_task_3]

    assert File.rm!(@log_file_path) == :ok
  end

  test "removes tasks from the log" do
    {:ok, start_time, 0} = DateTime.from_iso8601("2018-12-21T01:02:03Z")

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

    assert Persistence.Log.add(Store, expected_task_1) == :ok
    assert Persistence.Log.add(Store, expected_task_2) == :ok
    assert Persistence.Log.add(Store, expected_task_3) == :ok

    tasks_stream =
      File.stream!(@log_file_path)
      |> Stream.map(&String.replace(&1, "\n", ""))
      |> Stream.map(fn raw_entry -> Poison.decode!(raw_entry, as: %Api.Task{}) end)
      |> Stream.map(fn entry ->
        {:ok, start, 0} = DateTime.from_iso8601(entry.start)
        %{entry | start: start}
      end)

    tasks = tasks_stream |> Enum.to_list()
    assert tasks == [expected_task_1, expected_task_2, expected_task_3]

    assert Persistence.Log.remove(Store, expected_task_2.id) == :ok
    tasks = tasks_stream |> Enum.to_list()
    assert tasks == [expected_task_1, expected_task_3]

    assert Persistence.Log.remove(Store, expected_task_1.id) == :ok
    tasks = tasks_stream |> Enum.to_list()
    assert tasks == [expected_task_3]

    assert Persistence.Log.remove(Store, expected_task_3.id) == :ok
    tasks = tasks_stream |> Enum.to_list()
    assert tasks == []

    assert File.rm!(@log_file_path) == :ok
  end

  test "lists tasks in the log" do
    {:ok, start_time, 0} = DateTime.from_iso8601("2018-12-21T01:02:03Z")

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

    assert Persistence.Log.add(Store, expected_task_1) == :ok
    assert Persistence.Log.add(Store, expected_task_2) == :ok
    assert Persistence.Log.add(Store, expected_task_3) == :ok

    {:ok, tasks_stream} = Persistence.Log.list(Store)
    tasks_stream = tasks_stream |> Stream.map(fn {:ok, task} -> task end)

    assert Enum.to_list(tasks_stream) == [expected_task_1, expected_task_2, expected_task_3]

    assert File.rm!(@log_file_path) == :ok
  end

  test "process commands" do
    {:ok, start_time, 0} = DateTime.from_iso8601("2018-12-21T01:02:03Z")

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

    assert Persistence.Log.add(Store, expected_task_1) == :ok
    assert Persistence.Log.add(Store, expected_task_2) == :ok
    assert Persistence.Log.add(Store, expected_task_3) == :ok

    {:ok, tasks_stream} = Persistence.Log.list(Store)
    tasks_stream = tasks_stream |> Stream.map(fn {:ok, task} -> task end)

    assert Enum.to_list(tasks_stream) == [expected_task_1, expected_task_2, expected_task_3]

    assert Persistence.Log.process_command(Store, ["clear"]) == :ok

    assert Enum.to_list(tasks_stream) == []

    assert File.rm!(@log_file_path) == :ok
  end
end
