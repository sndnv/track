defmodule Aggregate.TasksTest do
  @moduledoc false

  use ExUnit.Case

  @day_minutes 24 * 60
  @day_seconds @day_minutes * 60

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

  test "splits an entry covering more than one day into entries for each day" do
    {:ok, start_day} = Date.from_iso8601("1999-12-21")
    {:ok, start_time} = NaiveDateTime.from_iso8601("#{start_day |> Date.to_string()}T12:30:00")

    task = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task1",
      start: start_time,
      duration: 60
    }

    expected_tasks = [{task, start_day}]

    actual_tasks = Aggregate.Tasks.split_task_per_day(task)

    assert expected_tasks == actual_tasks

    task = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task1",
      start: start_time,
      duration: 3 * @day_minutes
    }

    {:ok, next_start} =
      NaiveDateTime.from_iso8601("#{start_day |> Date.add(1) |> Date.to_string()}T00:00:00")

    {:ok, first_day_end_time} =
      NaiveDateTime.from_iso8601("#{start_day |> Date.to_string()}T23:59:59")

    first_day_end_time = first_day_end_time |> NaiveDateTime.add(1, :second)

    first_day_remaining_mintues =
      div(NaiveDateTime.diff(first_day_end_time, start_time, :second), 60)

    last_day_minutes = @day_minutes - first_day_remaining_mintues

    expected_tasks = [
      {
        %{
          task
          | start: next_start |> NaiveDateTime.add(2 * @day_seconds, :second),
            duration: last_day_minutes
        },
        start_day |> Date.add(3)
      },
      {
        %{
          task
          | start: next_start |> NaiveDateTime.add(1 * @day_seconds, :second),
            duration: @day_minutes
        },
        start_day |> Date.add(2)
      },
      {
        %{task | start: next_start, duration: @day_minutes},
        start_day |> Date.add(1)
      },
      {
        %{task | duration: first_day_remaining_mintues},
        start_day
      }
    ]

    actual_tasks = Aggregate.Tasks.split_task_per_day(task)

    assert actual_tasks == expected_tasks
  end

  test "converts a task's start day to period start" do
    {:ok, start_day} = Date.from_iso8601("1999-12-21")
    assert Aggregate.Tasks.task_start_day_to_period(start_day, :day) == "1999-12-21"
    assert Aggregate.Tasks.task_start_day_to_period(start_day, :week) == "1999-12-20"
    assert Aggregate.Tasks.task_start_day_to_period(start_day, :month) == "1999-12"
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

  test "aggregates a stream of tasks to a list of tasks per period" do
    tasks = Cli.Fixtures.mock_tasks()
    tasks_start_date = Enum.at(tasks, 0).start |> NaiveDateTime.to_date()

    task_4_start_date = tasks_start_date |> Date.add(2)

    expected_task_4 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: Enum.at(tasks, 0).start |> NaiveDateTime.add(2 * @day_seconds, :second),
      duration: 45
    }

    task_5_start_date = tasks_start_date |> Date.add(5)

    expected_task_5 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: Enum.at(tasks, 0).start |> NaiveDateTime.add(5 * @day_seconds, :second),
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
      duration: 3 * @day_minutes
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
      Aggregate.Tasks.per_period(stream, query, :day)
      |> Enum.map(fn {date, duration, entries} ->
        {date, duration, entries |> Enum.map(fn entry -> entry.id end)}
      end)

    expected_aggregation = [
      {task_6_start_date_p3 |> Date.to_string(), @day_minutes, [expected_task_6.id]},
      {task_6_start_date_p2 |> Date.to_string(), @day_minutes, [expected_task_6.id]},
      {task_6_start_date_p1 |> Date.to_string(), @day_minutes, [expected_task_6.id]},
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
      Aggregate.Tasks.per_period(stream, query, :day)
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
      Aggregate.Tasks.per_period(stream, query, :day)
      |> Enum.map(fn {date, duration, entries} ->
        {date, duration, entries |> Enum.map(fn entry -> entry.id end)}
      end)

    expected_aggregation = [
      {task_5_start_date |> Date.to_string(), 18, [expected_task_5.id]},
      {task_4_start_date |> Date.to_string(), 45, [expected_task_4.id]},
      {tasks_start_date |> Date.to_string(), 90, tasks |> Enum.map(fn entry -> entry.id end)},
      {task_6_start_date_p1 |> Date.to_string(), @day_minutes, [expected_task_6.id]},
      {task_6_start_date_p2 |> Date.to_string(), @day_minutes, [expected_task_6.id]},
      {task_6_start_date_p3 |> Date.to_string(), @day_minutes, [expected_task_6.id]}
    ]

    assert actual_aggregation == expected_aggregation

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "start",
      order: "desc"
    }

    actual_aggregation =
      Aggregate.Tasks.per_period(stream, query, :week)
      |> Enum.map(fn {date, duration, entries} ->
        {date, duration, entries |> Enum.map(fn entry -> entry.id end)}
      end)

    expected_aggregation = [
      {task_6_start_date_p1 |> monday_of_date, 3 * @day_minutes,
       [expected_task_6.id, expected_task_6.id, expected_task_6.id]},
      {task_5_start_date |> monday_of_date, 18, [expected_task_5.id]},
      {tasks_start_date |> monday_of_date, 135,
       (tasks |> Enum.map(fn entry -> entry.id end)) ++ [expected_task_4.id]}
    ]

    assert actual_aggregation == expected_aggregation

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "start",
      order: "desc"
    }

    actual_aggregation =
      Aggregate.Tasks.per_period(stream, query, :month)
      |> Enum.map(fn {date, duration, entries} ->
        {date, duration, entries |> Enum.map(fn entry -> entry.id end)}
      end)

    expected_aggregation = [
      {task_6_start_date_p3 |> month_of_date(), 3 * @day_minutes,
       [expected_task_6.id, expected_task_6.id, expected_task_6.id]},
      {tasks_start_date |> month_of_date(), 153,
       (tasks |> Enum.map(fn entry -> entry.id end)) ++ [expected_task_4.id, expected_task_5.id]}
    ]

    assert actual_aggregation == expected_aggregation
  end

  test "aggregates a stream of tasks to a list of durations for a task for a period" do
    tasks = Cli.Fixtures.mock_tasks()

    expected_task_4 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: Enum.at(tasks, 0).start |> NaiveDateTime.add(2 * @day_seconds, :second),
      duration: 45
    }

    expected_task_5 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: Enum.at(tasks, 0).start |> NaiveDateTime.add(5 * @day_seconds, :second),
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
      duration: 3 * @day_minutes
    }

    stream =
      Cli.Fixtures.mock_tasks_stream(tasks ++ [expected_task_4, expected_task_5, expected_task_6])

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "start",
      order: "desc"
    }

    task_regex = ~r/task6/

    actual_aggregation =
      Aggregate.Tasks.per_period_for_a_task(stream, query, task_regex, :day)
      |> Enum.map(fn {date, duration, entries} ->
        {date, duration, entries |> Enum.map(fn entry -> entry.id end)}
      end)

    expected_aggregation = [
      {task_6_start_date_p3 |> Date.to_string(), @day_minutes, [expected_task_6.id]},
      {task_6_start_date_p2 |> Date.to_string(), @day_minutes, [expected_task_6.id]},
      {task_6_start_date_p1 |> Date.to_string(), @day_minutes, [expected_task_6.id]}
    ]

    assert actual_aggregation == expected_aggregation

    task_regex = ~r/notask/

    actual_aggregation =
      Aggregate.Tasks.per_period_for_a_task(stream, query, task_regex, :day)
      |> Enum.map(fn {date, duration, entries} ->
        {date, duration, entries |> Enum.map(fn entry -> entry.id end)}
      end)

    expected_aggregation = []

    assert actual_aggregation == expected_aggregation
  end

  defp monday_of_date(date) do
    week_monday =
      Date.add(
        date,
        -(Calendar.ISO.day_of_week(date.year, date.month, date.day) - 1)
      )

    week_monday |> Date.to_string()
  end

  defp month_of_date(date) do
    "#{date.year}-#{date.month |> Integer.to_string() |> String.pad_leading(2, "0")}"
  end
end
