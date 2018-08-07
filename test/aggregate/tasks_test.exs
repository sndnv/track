defmodule Aggregate.TasksTest do
  @moduledoc false

  use ExUnit.Case

  test "convert date/time to string" do
    {:ok, dt} = NaiveDateTime.from_iso8601("2018-12-21T01:02:03Z")
    assert Aggregate.Tasks.naive_date_time_to_string(dt) == "2018-12-21 01:02"

    {:ok, dt} = NaiveDateTime.from_iso8601("2018-03-04T00:00:03Z")
    assert Aggregate.Tasks.naive_date_time_to_string(dt) == "2018-03-04 00:00"

    {:ok, dt} = NaiveDateTime.from_iso8601("2000-01-01T00:01:02Z")
    assert Aggregate.Tasks.naive_date_time_to_string(dt) == "2000-01-01 00:01"
  end

  test "convert a list of tasks to table rows" do
    tasks = mock_tasks()

    expected_rows = [
      [
        Enum.at(tasks, 0).id,
        Enum.at(tasks, 0).task,
        Aggregate.Tasks.naive_date_time_to_string(Enum.at(tasks, 0).start),
        "#{Enum.at(tasks, 0).duration} m"
      ],
      [
        Enum.at(tasks, 1).id,
        Enum.at(tasks, 1).task,
        Aggregate.Tasks.naive_date_time_to_string(Enum.at(tasks, 1).start),
        "#{Enum.at(tasks, 1).duration} m"
      ],
      [
        Enum.at(tasks, 2).id,
        Enum.at(tasks, 2).task,
        Aggregate.Tasks.naive_date_time_to_string(Enum.at(tasks, 2).start),
        "#{Enum.at(tasks, 2).duration} m"
      ]
    ]

    assert Aggregate.Tasks.to_table_rows(tasks) == expected_rows
  end

  test "sort a list of tasks" do
    tasks = mock_tasks()

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "task"
    }

    assert Aggregate.Tasks.sorted(tasks, query) == [
             Enum.at(tasks, 2),
             Enum.at(tasks, 1),
             Enum.at(tasks, 0)
           ]

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "start"
    }

    assert Aggregate.Tasks.sorted(tasks, query) == [
             Enum.at(tasks, 1),
             Enum.at(tasks, 2),
             Enum.at(tasks, 0)
           ]

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "duration"
    }

    assert Aggregate.Tasks.sorted(tasks, query) == [
             Enum.at(tasks, 0),
             Enum.at(tasks, 2),
             Enum.at(tasks, 1)
           ]
  end

  test "convert a stream of tasks to a list of tasks" do
    tasks = mock_tasks()
    stream = mock_tasks_stream(tasks)
    assert Aggregate.Tasks.as_list(stream) == tasks
  end

  test "convert tasks start date/time from UTC to the local time zone" do
    tasks = mock_tasks()
    stream = mock_tasks_stream(tasks)

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

  test "convert a stream of tasks to a table" do
    tasks = mock_tasks()
    stream = mock_tasks_stream(tasks)

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "task"
    }

    table_header_size = 3
    table_footer_size = 1
    expected_table_size = table_header_size + length(tasks) + table_footer_size
    {:ok, actual_table} = Aggregate.Tasks.list_to_table(stream, query)
    actual_table_size = actual_table |> String.split("\n", trim: true) |> length()

    assert actual_table_size == expected_table_size
  end

  defp mock_tasks() do
    {:ok, start_time} = NaiveDateTime.from_iso8601("2018-12-21T01:02:03Z")

    expected_task_1 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task1",
      start: NaiveDateTime.add(start_time, 10, :second),
      duration: 60
    }

    expected_task_2 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task2",
      start: NaiveDateTime.add(start_time, 90, :second),
      duration: 10
    }

    expected_task_3 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: NaiveDateTime.add(start_time, 20, :second),
      duration: 20
    }

    [expected_task_1, expected_task_2, expected_task_3]
  end

  defp mock_tasks_stream(tasks) do
    Stream.map(tasks, fn e -> e end)
  end
end
