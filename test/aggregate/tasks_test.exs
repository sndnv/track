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

  test "aggregates a stream of tasks to list of tasks per day" do
    day_seconds = 24 * 60 * 60

    tasks = Cli.Fixtures.mock_tasks()
    tasks_start_date = Enum.at(tasks, 0).start |> NaiveDateTime.to_date()

    task_4_start_date = tasks_start_date |> Date.add(2)

    expected_task_4 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: Enum.at(tasks, 0).start |> NaiveDateTime.add(2 * day_seconds, :second),
      duration: 45
    }

    task_5_start_date = tasks_start_date |> Date.add(5)

    expected_task_5 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: Enum.at(tasks, 0).start |> NaiveDateTime.add(5 * day_seconds, :second),
      duration: 18
    }

    {:ok, task_6_start_date_p1} = NaiveDateTime.from_iso8601("2020-10-20T00:00:00")

    [task_6_start_date] =
      task_6_start_date_p1
      |> NaiveDateTime.to_erl()
      |> :calendar.local_time_to_universal_time_dst()
      |> Enum.map(fn dt -> NaiveDateTime.from_erl!(dt) end)

    task_6_start_date_p2 = task_6_start_date_p1 |> Date.add(1)
    task_6_start_date_p3 = task_6_start_date_p1 |> Date.add(2)

    expected_task_6 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task6",
      start: task_6_start_date,
      duration: 3 * 24 * 60
    }

    stream =
      Cli.Fixtures.mock_tasks_stream(tasks ++ [expected_task_4, expected_task_5, expected_task_6])

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "start",
      order: "desc"
    }

    actual_aggregation =
      Aggregate.Tasks.per_day(stream, query)
      |> Enum.map(fn {date, duration, entries} ->
        {date, duration, entries |> Enum.map(fn entry -> entry.id end)}
      end)

    expected_aggregation = [
      {task_6_start_date_p3 |> Date.to_string(), 24 * 60, [expected_task_6.id]},
      {task_6_start_date_p2 |> Date.to_string(), 24 * 60, [expected_task_6.id]},
      {task_6_start_date_p1 |> Date.to_string(), 24 * 60, [expected_task_6.id]},
      {task_5_start_date |> Date.to_string(), 18, [expected_task_5.id]},
      {task_4_start_date |> Date.to_string(), 45, [expected_task_4.id]},
      {tasks_start_date |> Date.to_string(), 90, tasks |> Enum.map(fn entry -> entry.id end)}
    ]

    assert actual_aggregation == expected_aggregation

    # sorting by task is not supported; defaults to sorting by start date
    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "task",
      order: "asc"
    }

    actual_aggregation =
      Aggregate.Tasks.per_day(stream, query)
      |> Enum.map(fn {date, duration, entries} ->
        {date, duration, entries |> Enum.map(fn entry -> entry.id end)}
      end)

    assert actual_aggregation == expected_aggregation |> Enum.reverse()

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "duration",
      order: "asc"
    }

    actual_aggregation =
      Aggregate.Tasks.per_day(stream, query)
      |> Enum.map(fn {date, duration, entries} ->
        {date, duration, entries |> Enum.map(fn entry -> entry.id end)}
      end)

    expected_aggregation = [
      {task_5_start_date |> Date.to_string(), 18, [expected_task_5.id]},
      {task_4_start_date |> Date.to_string(), 45, [expected_task_4.id]},
      {tasks_start_date |> Date.to_string(), 90, tasks |> Enum.map(fn entry -> entry.id end)},
      {task_6_start_date_p1 |> Date.to_string(), 24 * 60, [expected_task_6.id]},
      {task_6_start_date_p2 |> Date.to_string(), 24 * 60, [expected_task_6.id]},
      {task_6_start_date_p3 |> Date.to_string(), 24 * 60, [expected_task_6.id]}
    ]

    assert actual_aggregation == expected_aggregation
  end
end
