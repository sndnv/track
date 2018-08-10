defmodule Persistence.StoreBehaviour do
  @moduledoc false

  use ExUnit.CaseTemplate

  def mock_tasks() do
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

    [expected_task_1, expected_task_2, expected_task_3]
  end

  def adds_tasks(store_type, store, task_query_fn) do
    expected_tasks = mock_tasks()

    assert store_type.add(store, Enum.at(expected_tasks, 0)) == :ok
    assert store_type.add(store, Enum.at(expected_tasks, 1)) == :ok
    assert store_type.add(store, Enum.at(expected_tasks, 2)) == :ok

    tasks = task_query_fn.()

    assert tasks == [
             Enum.at(expected_tasks, 0),
             Enum.at(expected_tasks, 1),
             Enum.at(expected_tasks, 2)
           ]

    :ok
  end

  def removes_tasks(store_type, store, task_query_fn) do
    expected_tasks = mock_tasks()

    assert store_type.add(store, Enum.at(expected_tasks, 0)) == :ok
    assert store_type.add(store, Enum.at(expected_tasks, 1)) == :ok
    assert store_type.add(store, Enum.at(expected_tasks, 2)) == :ok

    tasks = task_query_fn.()

    assert tasks == [
             Enum.at(expected_tasks, 0),
             Enum.at(expected_tasks, 1),
             Enum.at(expected_tasks, 2)
           ]

    assert store_type.remove(store, Enum.at(expected_tasks, 1).id) == :ok
    tasks = task_query_fn.()
    assert tasks == [Enum.at(expected_tasks, 0), Enum.at(expected_tasks, 2)]

    assert store_type.remove(store, Enum.at(expected_tasks, 0).id) == :ok
    tasks = task_query_fn.()
    assert tasks == [Enum.at(expected_tasks, 2)]

    assert store_type.remove(store, Enum.at(expected_tasks, 2).id) == :ok
    tasks = task_query_fn.()
    assert tasks == []

    :ok
  end

  def lists_tasks(store_type, store) do
    expected_tasks = mock_tasks()

    assert store_type.add(store, Enum.at(expected_tasks, 0)) == :ok
    assert store_type.add(store, Enum.at(expected_tasks, 1)) == :ok
    assert store_type.add(store, Enum.at(expected_tasks, 2)) == :ok

    {:ok, tasks_stream} = store_type.list(store)
    tasks_stream = tasks_stream |> Stream.map(fn {:ok, task} -> task end)

    assert Enum.to_list(tasks_stream) |> Enum.sort_by(fn entry -> entry.task end) == [
             Enum.at(expected_tasks, 0),
             Enum.at(expected_tasks, 1),
             Enum.at(expected_tasks, 2)
           ]

    :ok
  end

  def processes_commands(store_type, store) do
    expected_tasks = mock_tasks()

    assert store_type.add(store, Enum.at(expected_tasks, 0)) == :ok
    assert store_type.add(store, Enum.at(expected_tasks, 1)) == :ok
    assert store_type.add(store, Enum.at(expected_tasks, 2)) == :ok

    {:ok, tasks_stream} = store_type.list(store)
    tasks_stream = tasks_stream |> Stream.map(fn {:ok, task} -> task end)

    assert Enum.to_list(tasks_stream) |> Enum.sort_by(fn entry -> entry.task end) == [
             Enum.at(expected_tasks, 0),
             Enum.at(expected_tasks, 1),
             Enum.at(expected_tasks, 2)
           ]

    assert store_type.process_command(store, ["clear"]) == :ok

    {:ok, tasks_stream} = store_type.list(store)
    tasks_stream = tasks_stream |> Stream.map(fn {:ok, task} -> task end)

    assert Enum.to_list(tasks_stream) == []

    :ok
  end
end
