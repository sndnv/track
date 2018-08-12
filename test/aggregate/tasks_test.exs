defmodule Aggregate.TasksTest do
  @moduledoc false

  use ExUnit.Case

  test "converts a stream of tasks to a list of tasks" do
    tasks = Cli.Fixtures.mock_tasks()
    stream = Cli.Fixtures.mock_tasks_stream(tasks)
    assert Aggregate.Tasks.as_list(stream) == tasks
  end

  test "converts tasks start date/time from UTC to the local time zone" do
    tasks = Cli.Fixtures.mock_tasks()
    stream = Cli.Fixtures.mock_tasks_stream(tasks)

    expected_tasks =
      tasks
      |> Enum.map(fn entry ->
        start_with_time_zone =
          entry.start
          |> NaiveDateTime.to_erl()
          |> :calendar.universal_time_to_local_time()
          |> NaiveDateTime.from_erl!()

        %{entry | start: start_with_time_zone}
      end)

    actual_tasks = Aggregate.Tasks.with_local_time_zone(stream) |> Aggregate.Tasks.as_list()

    assert actual_tasks == expected_tasks
  end

  test "converts a stream of tasks to a sorted list of tasks" do
    tasks = Cli.Fixtures.mock_tasks()
    stream = Cli.Fixtures.mock_tasks_stream(tasks)
    tasks = tasks |> Aggregate.Tasks.with_local_time_zone()

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "task",
      order: "desc"
    }

    assert Aggregate.Tasks.as_sorted_list(stream, query) == [
             Enum.at(tasks, 2),
             Enum.at(tasks, 1),
             Enum.at(tasks, 0)
           ]

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "start",
      order: "desc"
    }

    assert Aggregate.Tasks.as_sorted_list(stream, query) == [
             Enum.at(tasks, 1),
             Enum.at(tasks, 2),
             Enum.at(tasks, 0)
           ]

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "duration",
      order: "desc"
    }

    assert Aggregate.Tasks.as_sorted_list(stream, query) == [
             Enum.at(tasks, 0),
             Enum.at(tasks, 2),
             Enum.at(tasks, 1)
           ]
  end

  test "aggregates a stream of tasks to a list of tasks with total duration" do
    tasks = Cli.Fixtures.mock_tasks()

    expected_task_4 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: Enum.at(tasks, 0).start,
      duration: 45
    }

    expected_task_5 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: Enum.at(tasks, 0).start,
      duration: 18
    }

    stream = Cli.Fixtures.mock_tasks_stream(tasks ++ [expected_task_4, expected_task_5])

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "task",
      order: "desc"
    }

    actual_aggregation =
      Aggregate.Tasks.with_total_duration(stream, query)
      |> Enum.map(fn {task, duration, _} -> {task, duration} end)

    assert actual_aggregation == [{"test-task3", 83}, {"test-task2", 10}, {"test-task1", 60}]

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "duration",
      order: "desc"
    }

    actual_aggregation =
      Aggregate.Tasks.with_total_duration(stream, query)
      |> Enum.map(fn {task, duration, _} -> {task, duration} end)

    assert actual_aggregation == [{"test-task3", 83}, {"test-task1", 60}, {"test-task2", 10}]

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "start",
      order: "desc"
    }

    actual_aggregation =
      Aggregate.Tasks.with_total_duration(stream, query)
      |> Enum.map(fn {task, duration, _} -> {task, duration} end)

    assert actual_aggregation == [{"test-task3", 83}, {"test-task1", 60}, {"test-task2", 10}]
  end

  test "filters all tasks with no duration" do
    tasks = Cli.Fixtures.mock_tasks()

    expected_task_4 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: Enum.at(tasks, 0).start,
      duration: 0
    }

    expected_task_5 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: Enum.at(tasks, 0).start,
      duration: 1
    }

    stream = Cli.Fixtures.mock_tasks_stream(tasks ++ [expected_task_4, expected_task_5])

    assert Aggregate.Tasks.with_no_duration(stream) == [expected_task_4]
  end
end
