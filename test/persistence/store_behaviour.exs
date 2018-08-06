defmodule Persistence.StoreBehaviour do
  @moduledoc false

  use ExUnit.CaseTemplate

  def adds_tasks(store_type, store, task_query_fn) do
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

    assert store_type.add(store, expected_task_1) == :ok
    assert store_type.add(store, expected_task_2) == :ok
    assert store_type.add(store, expected_task_3) == :ok

    tasks = task_query_fn.()

    assert tasks == [expected_task_1, expected_task_2, expected_task_3]

    :ok
  end

  def removes_tasks(store_type, store, task_query_fn) do
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

    assert store_type.add(store, expected_task_1) == :ok
    assert store_type.add(store, expected_task_2) == :ok
    assert store_type.add(store, expected_task_3) == :ok

    tasks = task_query_fn.()
    assert tasks == [expected_task_1, expected_task_2, expected_task_3]

    assert store_type.remove(store, expected_task_2.id) == :ok
    tasks = task_query_fn.()
    assert tasks == [expected_task_1, expected_task_3]

    assert store_type.remove(store, expected_task_1.id) == :ok
    tasks = task_query_fn.()
    assert tasks == [expected_task_3]

    assert store_type.remove(store, expected_task_3.id) == :ok
    tasks = task_query_fn.()
    assert tasks == []

    :ok
  end

  def lists_tasks(store_type, store) do
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

    assert store_type.add(store, expected_task_1) == :ok
    assert store_type.add(store, expected_task_2) == :ok
    assert store_type.add(store, expected_task_3) == :ok

    {:ok, tasks_stream} = store_type.list(store)
    tasks_stream = tasks_stream |> Stream.map(fn {:ok, task} -> task end)

    assert Enum.to_list(tasks_stream) |> Enum.sort_by(fn entry -> entry.task end) == [
             expected_task_1,
             expected_task_2,
             expected_task_3
           ]

    :ok
  end

  def processes_commands(store_type, store) do
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

    assert store_type.add(store, expected_task_1) == :ok
    assert store_type.add(store, expected_task_2) == :ok
    assert store_type.add(store, expected_task_3) == :ok

    {:ok, tasks_stream} = store_type.list(store)
    tasks_stream = tasks_stream |> Stream.map(fn {:ok, task} -> task end)

    assert Enum.to_list(tasks_stream) |> Enum.sort_by(fn entry -> entry.task end) == [
             expected_task_1,
             expected_task_2,
             expected_task_3
           ]

    assert store_type.process_command(store, ["clear"]) == :ok

    {:ok, tasks_stream} = store_type.list(store)
    tasks_stream = tasks_stream |> Stream.map(fn {:ok, task} -> task end)

    assert Enum.to_list(tasks_stream) == []

    :ok
  end
end
