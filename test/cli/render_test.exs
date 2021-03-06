defmodule Cli.RenderTest do
  @moduledoc false

  use ExUnit.Case

  @day_minutes 24 * 60
  @day_seconds @day_minutes * 60

  test "retrieves the current shell width" do
    default_shell_width = 1
    assert Cli.Render.get_shell_width(default_shell_width) > 0 == true
  end

  test "converts duration to a formatted string" do
    start = :calendar.local_time() |> NaiveDateTime.from_erl!()
    assert Cli.Render.duration_to_formatted_string(0, start) == "(A) 0:00"

    start = start |> NaiveDateTime.add(-120, :second)
    assert Cli.Render.duration_to_formatted_string(0, start) == "(A) 0:02"
    assert Cli.Render.duration_to_formatted_string(1, start) == "0:01"
    assert Cli.Render.duration_to_formatted_string(9, start) == "0:09"
    assert Cli.Render.duration_to_formatted_string(35, start) == "0:35"
    assert Cli.Render.duration_to_formatted_string(59, start) == "0:59"
    assert Cli.Render.duration_to_formatted_string(60, start) == "1:00"
    assert Cli.Render.duration_to_formatted_string(61, start) == "1:01"
    assert Cli.Render.duration_to_formatted_string(121, start) == "2:01"
    assert Cli.Render.duration_to_formatted_string(1000, start) == "16:40"
    assert Cli.Render.duration_to_formatted_string(-1000, start) == "16:40"
  end

  test "converts timestamps to string" do
    {:ok, dt} = NaiveDateTime.from_iso8601("2018-12-21T01:02:03")
    assert Cli.Render.naive_date_time_to_string(dt) == "2018-12-21 01:02"

    {:ok, dt} = NaiveDateTime.from_iso8601("2018-03-04T00:00:03")
    assert Cli.Render.naive_date_time_to_string(dt) == "2018-03-04 00:00"

    {:ok, dt} = NaiveDateTime.from_iso8601("2000-01-01T00:01:02")
    assert Cli.Render.naive_date_time_to_string(dt) == "2000-01-01 00:01"
  end

  test "converts a list of tasks to table rows" do
    start_time = NaiveDateTime.utc_now()

    expected_task_1 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task1",
      start: NaiveDateTime.add(start_time, 10, :second),
      duration: 60
    }

    expected_task_2 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task2",
      start: NaiveDateTime.add(start_time, 1 * @day_seconds, :second),
      duration: 10
    }

    expected_task_3 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: NaiveDateTime.add(start_time, -1 * @day_seconds, :second),
      duration: 10
    }

    expected_task_4 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task4",
      start: NaiveDateTime.add(start_time, 30 * @day_seconds, :second),
      duration: 20
    }

    expected_task_5 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task5",
      start: NaiveDateTime.add(start_time, -30 * @day_seconds, :second),
      duration: 20
    }

    expected_task_6 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task6",
      start: NaiveDateTime.add(start_time, 120 * @day_seconds, :second),
      duration: 20
    }

    expected_task_7 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task7",
      start: NaiveDateTime.add(start_time, -120 * @day_seconds, :second),
      duration: 20
    }

    tasks = [
      expected_task_1,
      expected_task_2,
      expected_task_3,
      expected_task_4,
      expected_task_5,
      expected_task_6,
      expected_task_7
    ]

    expected_rows =
      tasks
      |> Enum.map(fn task ->
        [
          task.id,
          task.task,
          Cli.Render.duration_to_formatted_string(task.duration, NaiveDateTime.utc_now())
        ]
      end)

    actual_rows =
      Cli.Render.to_table_rows(tasks)
      |> Enum.map(fn [id, task, _, duration] -> [id, task, duration] end)

    assert actual_rows == expected_rows
  end

  test "retrieves the current periods" do
    today = Date.utc_today()

    expected_current_day = Date.to_string(today)

    current_week_monday =
      Date.add(
        today,
        -(Calendar.ISO.day_of_week(today.year, today.month, today.day) - 1)
      )

    expected_current_week_days =
      Enum.map(0..6, fn week_day ->
        Date.to_string(Date.add(current_week_monday, week_day))
      end)

    expected_current_month =
      "#{today.year}-#{today.month |> Integer.to_string() |> String.pad_leading(2, "0")}"

    {_, actual_current_day, actual_current_week_days, actual_current_month} =
      Cli.Render.get_current_periods()

    assert expected_current_day == actual_current_day
    assert expected_current_week_days == actual_current_week_days
    assert expected_current_month == actual_current_month
  end

  test "calculates the period range of a timestamp" do
    current_periods = Cli.Render.get_current_periods()

    today = NaiveDateTime.utc_now()
    today_string = today |> Cli.Render.naive_date_time_to_string()

    assert Cli.Render.naive_date_time_to_period(today, today_string, current_periods) ==
             :current_day

    {:ok, past} = NaiveDateTime.from_iso8601("1999-12-21T01:02:03")
    past_string = Cli.Render.naive_date_time_to_string(past)
    assert Cli.Render.naive_date_time_to_period(past, past_string, current_periods) == :past

    {:ok, future} = NaiveDateTime.from_iso8601("2999-12-21T01:02:03")
    future_string = Cli.Render.naive_date_time_to_string(future)
    assert Cli.Render.naive_date_time_to_period(future, future_string, current_periods) == :future
  end

  test "converts time periods to colours for charts" do
    assert Cli.Render.period_to_colour(:future) == :blue
    assert Cli.Render.period_to_colour(:current_day) == :green
    assert Cli.Render.period_to_colour(:current_week) == :yellow
    assert Cli.Render.period_to_colour(:current_month) == :red
    assert Cli.Render.period_to_colour(:past) == :default
  end

  test "creates a chart segment for an entry" do
    assert Cli.Render.entry_chart_segment("+", 3) == ["+", "+", "+"]
    assert Cli.Render.entry_chart_segment("+", 4) == ["+", "+", "+", "+"]
    assert Cli.Render.entry_chart_segment("+", 5) == ["+", "+", "+", "+", "+"]

    assert Cli.Render.coloured_entry_chart_segment("+", 3, :red) == [
             [[[[[] | "\e[31m"], "+"], "+"], "+"] | "\e[0m"
           ]
  end

  test "generates a bar chart" do
    header = [label: "TestLabel", value_label: "TestValue"]
    footer = [label: "Test Footer"]

    rows = [
      {"test-label-#1", 120, "__120 ", [{20, :red}, {75, :yellow}, {25, :default}]},
      {"test-label-#2", 50, "--50 ", [{35, :cyan}, {5, :default}, {5, :default}, {5, :default}]},
      {"test-label-#3", 15, "15 ", [{15, :green}]}
    ]

    expected_chart_opt_1 = [
      "TestLabel     | TestValue",
      "------------- + ---------",
      "test-label-#1 | __120 ▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇\e[33m▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇\e[0m\e[31m▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇\e[0m",
      "test-label-#2 |  --50 ▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇\e[36m▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇\e[0m",
      "test-label-#3 |    15 \e[32m▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇\e[0m",
      "------------- + ---------",
      "Test Footer"
    ]

    expected_chart_opt_2 = [
      "TestLabel     | TestValue",
      "------------- + ---------",
      "test-label-#1 | __120 ▇▇▇▇▇▇▇▇▇▇▇▇▇\e[33m▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇\e[0m\e[31m▇▇▇▇▇▇▇▇▇\e[0m",
      "test-label-#2 |  --50 ▇▇▇▇▇▇▇▇\e[36m▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇\e[0m",
      "test-label-#3 |    15 \e[32m▇▇▇▇▇▇▇\e[0m",
      "------------- + ---------",
      "Test Footer"
    ]

    actual_chart = Cli.Render.bar_chart(header, rows, footer) |> String.split("\n")

    assert actual_chart == expected_chart_opt_1 || actual_chart == expected_chart_opt_2
  end

  test "generates the period-colour legend" do
    expected_legend =
      [
        " \e[32m▇\e[0m -> Today's tasks",
        " \e[33m▇\e[0m -> This week's tasks",
        " \e[31m▇\e[0m -> This month's tasks",
        " \e[34m▇\e[0m -> Future tasks",
        " ▇ -> Older tasks"
      ]
      |> Enum.join("\n")

    assert Cli.Render.period_colour_legend() == expected_legend
  end

  test "generates group data from period data" do
    current_periods = Cli.Render.get_current_periods()

    {:ok, expected_group_start} = NaiveDateTime.from_iso8601("1999-12-21T00:00:00")
    expected_data = {:default, expected_group_start}
    actual_data = Cli.Render.group_data_from_period_data(:day, "1999-12-21", current_periods)
    assert expected_data == actual_data

    {:ok, expected_group_start} = NaiveDateTime.from_iso8601("1999-12-21T00:00:00")
    expected_data = {:default, expected_group_start}
    actual_data = Cli.Render.group_data_from_period_data(:week, "1999-12-21", current_periods)
    assert expected_data == actual_data

    {:ok, expected_group_start} = NaiveDateTime.from_iso8601("1999-12-01T00:00:00")
    expected_data = {:default, expected_group_start}
    actual_data = Cli.Render.group_data_from_period_data(:month, "1999-12", current_periods)
    assert expected_data == actual_data
  end

  test "converts a stream of tasks to a table" do
    tasks = Cli.Fixtures.mock_tasks()
    stream = Cli.Fixtures.mock_tasks_stream(tasks)

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "task",
      order: "asc"
    }

    table_header_size = 3
    table_footer_size = 1
    expected_table_size = table_header_size + length(tasks) + table_footer_size

    {:ok, actual_table} =
      stream |> Aggregate.Tasks.as_sorted_list(query) |> Cli.Render.tasks_table()

    actual_table_size = actual_table |> String.split("\n", trim: true) |> length()

    assert actual_table_size == expected_table_size
  end

  test "converts a stream of overlapping tasks to a table" do
    tasks = Cli.Fixtures.mock_tasks()
    stream = Cli.Fixtures.mock_tasks_stream(tasks)

    table_header_size = 3
    table_footer_size = 1
    # one task is currently active and it is not considered as overlapping
    overlapping_tasks = length(tasks) - 1
    expected_table_size = table_header_size + overlapping_tasks + table_footer_size

    {:ok, actual_table} =
      stream |> Aggregate.Tasks.with_overlapping_periods() |> Cli.Render.overlapping_tasks_table()

    actual_table_size = actual_table |> String.split("\n", trim: true) |> length()

    assert actual_table_size == expected_table_size
  end

  test "converts tasks grouped by duration to a bar chart" do
    tasks = Cli.Fixtures.mock_tasks()

    expected_task_4 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: NaiveDateTime.utc_now(),
      duration: 45
    }

    expected_task_5 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(@day_seconds, :second),
      duration: 100
    }

    expected_task_6 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(-@day_seconds, :second),
      duration: 85
    }

    expected_task_7 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(10 * @day_seconds, :second),
      duration: 100
    }

    expected_task_8 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(-10 * @day_seconds, :second),
      duration: 85
    }

    expected_task_9 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(120 * @day_seconds, :second),
      duration: 85
    }

    expected_task_10 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(-120 * @day_seconds, :second),
      duration: 85
    }

    stream =
      Cli.Fixtures.mock_tasks_stream(
        tasks ++
          [
            expected_task_4,
            expected_task_5,
            expected_task_6,
            expected_task_7,
            expected_task_8,
            expected_task_9,
            expected_task_10
          ]
      )

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "task",
      order: "asc"
    }

    chart_header_size = 2
    chart_footer_size = 2
    expected_aggregated_tasks = 4

    expected_chart_size = expected_aggregated_tasks + chart_header_size + chart_footer_size

    {:ok, actual_chart} =
      stream
      |> Aggregate.Tasks.with_total_duration(query)
      |> Cli.Render.duration_aggregation_as_bar_chart(query)

    actual_chart_size = actual_chart |> String.split("\n", trim: true) |> length()

    assert actual_chart_size == expected_chart_size
  end

  test "converts tasks grouped by period to a bar chart" do
    tasks = Cli.Fixtures.mock_tasks()

    expected_task_4 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: NaiveDateTime.utc_now(),
      duration: 45
    }

    expected_task_5 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(-@day_seconds, :second),
      duration: 100
    }

    expected_task_6 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(@day_seconds, :second),
      duration: 3 * @day_minutes
    }

    stream =
      Cli.Fixtures.mock_tasks_stream(
        tasks ++
          [
            expected_task_4,
            expected_task_5,
            expected_task_6
          ]
      )

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "task",
      order: "asc"
    }

    chart_header_size = 2
    chart_footer_size = 2
    # 3 tasks on the same day (from mock_tasks()) (1)
    # + 1 task per day (from tasks 4 and 5) (3)
    # + 1 task over 3 days (from task 6) (3)
    expected_aggregated_tasks = 7

    expected_chart_size = expected_aggregated_tasks + chart_header_size + chart_footer_size

    {:ok, actual_chart} =
      stream
      |> Aggregate.Tasks.per_period(query, :day)
      |> Cli.Render.period_aggregation_as_bar_chart(query, :day)

    actual_chart_size = actual_chart |> String.split("\n", trim: true) |> length()

    assert actual_chart_size == expected_chart_size

    expected_task_7 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(7 * @day_seconds, :second),
      duration: 3 * @day_minutes
    }

    expected_task_8 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(-7 * @day_seconds, :second),
      duration: 3 * @day_minutes
    }

    stream =
      Cli.Fixtures.mock_tasks_stream(
        tasks ++
          [
            expected_task_4,
            expected_task_5,
            expected_task_6,
            expected_task_7,
            expected_task_8
          ]
      )

    chart_header_size = 2
    chart_footer_size = 2
    # 3 tasks on the same day (from mock_tasks()) (1)
    # + 1 task for current week (from tasks 4, 5 and 6) (1)
    # + 1 task for next week (from task 7) (1)
    # + 1 task for previous week (from task 8) (1)
    expected_aggregated_tasks = 4
    # + 1 for previous/next day (from tasks 4, 5 and 6)
    # + 1 for previous/next week (from tasks 7 and 8)
    max_variation = 2

    expected_chart_size = expected_aggregated_tasks + chart_header_size + chart_footer_size

    {:ok, actual_chart} =
      stream
      |> Aggregate.Tasks.per_period(query, :week)
      |> Cli.Render.period_aggregation_as_bar_chart(query, :week)

    actual_chart_size = actual_chart |> String.split("\n", trim: true) |> length()

    assert actual_chart_size >= expected_chart_size - max_variation
    assert actual_chart_size <= expected_chart_size + max_variation

    expected_task_7 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(31 * @day_seconds, :second),
      duration: 3 * @day_minutes
    }

    expected_task_8 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(-31 * @day_seconds, :second),
      duration: 3 * @day_minutes
    }

    stream =
      Cli.Fixtures.mock_tasks_stream(
        tasks ++
          [
            expected_task_4,
            expected_task_5,
            expected_task_6,
            expected_task_7,
            expected_task_8
          ]
      )

    chart_header_size = 2
    chart_footer_size = 2
    # 3 tasks on the same day (from mock_tasks()) (1)
    # + 1 task for current week (from tasks 4, 5 and 6) (1)
    # + 1 task for next month (from task 7) (1)
    # + 1 task for next month (from task 9) (1)
    expected_aggregated_tasks = 4
    # + 1 for previous/next day (from tasks 4, 5 and 6)
    # + 1 for previous/next week (from tasks 7 and 8)
    max_variation = 2

    expected_chart_size = expected_aggregated_tasks + chart_header_size + chart_footer_size

    {:ok, actual_chart} =
      stream
      |> Aggregate.Tasks.per_period(query, :month)
      |> Cli.Render.period_aggregation_as_bar_chart(query, :month)

    actual_chart_size = actual_chart |> String.split("\n", trim: true) |> length()

    assert actual_chart_size >= expected_chart_size - max_variation
    assert actual_chart_size <= expected_chart_size + max_variation
  end

  test "converts a task's data grouped by period to a line chart" do
    tasks = Cli.Fixtures.mock_tasks()

    expected_task_4 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: NaiveDateTime.utc_now(),
      duration: 45
    }

    expected_task_5 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: Enum.at(tasks, 0).start |> NaiveDateTime.add(-@day_seconds, :second),
      duration: 100
    }

    expected_task_6 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: Enum.at(tasks, 0).start |> NaiveDateTime.add(@day_seconds, :second),
      duration: 3 * @day_minutes
    }

    stream =
      Cli.Fixtures.mock_tasks_stream(
        tasks ++
          [
            expected_task_4,
            expected_task_5,
            expected_task_6
          ]
      )

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "task",
      order: "asc"
    }

    expected_chart_size = 27

    task_regex = ~r/.*/

    {:ok, actual_chart} =
      stream
      |> Aggregate.Tasks.per_period_for_a_task(query, task_regex, :day)
      |> Cli.Render.task_aggregation_as_line_chart(query, task_regex, :day)

    actual_chart_size = actual_chart |> String.split("\n", trim: true) |> length()

    assert actual_chart_size == expected_chart_size
  end
end
