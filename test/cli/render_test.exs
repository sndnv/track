defmodule Cli.RenderTest do
  @moduledoc false

  use ExUnit.Case

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
    day_seconds = 24 * 60 * 60
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
      start: NaiveDateTime.add(start_time, 1 * day_seconds, :second),
      duration: 10
    }

    expected_task_3 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: NaiveDateTime.add(start_time, -1 * day_seconds, :second),
      duration: 10
    }

    expected_task_4 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task4",
      start: NaiveDateTime.add(start_time, 30 * day_seconds, :second),
      duration: 20
    }

    expected_task_5 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task5",
      start: NaiveDateTime.add(start_time, -30 * day_seconds, :second),
      duration: 20
    }

    expected_task_6 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task6",
      start: NaiveDateTime.add(start_time, 120 * day_seconds, :second),
      duration: 20
    }

    expected_task_7 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task7",
      start: NaiveDateTime.add(start_time, -120 * day_seconds, :second),
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

    day_seconds = 24 * 60 * 60

    today = NaiveDateTime.utc_now()
    today_string = today |> Cli.Render.naive_date_time_to_string()

    assert Cli.Render.naive_date_time_to_period(today, today_string, current_periods) ==
             :current_day

    today_p1 =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(day_seconds, :second)

    today_p1_string = today_p1 |> Cli.Render.naive_date_time_to_string()

    today_m1 =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-day_seconds, :second)

    today_m1_string = today_m1 |> Cli.Render.naive_date_time_to_string()

    today_p1 = Cli.Render.naive_date_time_to_period(today_p1, today_p1_string, current_periods)
    today_m1 = Cli.Render.naive_date_time_to_period(today_m1, today_m1_string, current_periods)
    assert today_p1 == :current_week || today_m1 == :current_week

    today = Date.utc_today()

    current_month =
      "#{today.year}-#{today.month |> Integer.to_string() |> String.pad_leading(2, "0")}"

    current_month_beginning_string = "#{current_month}-03T00:00:00"

    {:ok, current_month_beginning} =
      current_month_beginning_string |> NaiveDateTime.from_iso8601()

    current_month_middle_string = "#{current_month}-15T00:00:00"
    {:ok, current_month_middle} = current_month_beginning_string |> NaiveDateTime.from_iso8601()

    current_month_end_string = "#{current_month}-25T00:00:00"
    {:ok, current_month_end} = current_month_beginning_string |> NaiveDateTime.from_iso8601()

    current_month_beginning =
      Cli.Render.naive_date_time_to_period(
        current_month_beginning,
        current_month_beginning_string,
        current_periods
      )

    current_month_middle =
      Cli.Render.naive_date_time_to_period(
        current_month_middle,
        current_month_middle_string,
        current_periods
      )

    current_month_end =
      Cli.Render.naive_date_time_to_period(
        current_month_end,
        current_month_end_string,
        current_periods
      )

    assert current_month_beginning == :current_month || current_month_middle == :current_month ||
             current_month_end == :current_month

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

    expected_chart = [
      "TestLabel     | TestValue",
      "------------- + ---------",
      "test-label-#1 | __120 \e[31m▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇\e[0m\e[33m▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇\e[0m▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇",
      "test-label-#2 |  --50 \e[36m▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇\e[0m▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇",
      "test-label-#3 |    15 \e[32m▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇\e[0m",
      "------------- + ---------",
      "Test Footer"
    ]

    actual_chart = Cli.Render.bar_chart(header, rows, footer) |> String.split("\n")

    assert actual_chart == expected_chart
  end

  test "generates the period-colour legend" do
    expected_legend = [
      " \e[32m▇\e[0m -> Today's tasks",
      " \e[33m▇\e[0m -> This week's tasks",
      " \e[31m▇\e[0m -> This month's tasks",
      " \e[34m▇\e[0m -> Future tasks",
      " ▇ -> Older tasks"
    ]

    assert Cli.Render.period_colour_legend() == expected_legend
  end

  test "converts a stream of tasks to a table" do
    tasks = Cli.Fixtures.mock_tasks()
    stream = Cli.Fixtures.mock_tasks_stream(tasks)

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "task"
    }

    table_header_size = 3
    table_footer_size = 1
    expected_table_size = table_header_size + length(tasks) + table_footer_size

    {:ok, actual_table} = stream |> Aggregate.Tasks.as_sorted_list(query) |> Cli.Render.table()

    actual_table_size = actual_table |> String.split("\n", trim: true) |> length()

    assert actual_table_size == expected_table_size
  end

  test "converts aggregated tasks to a bar chart" do
    day_seconds = 24 * 60 * 60

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
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(day_seconds, :second),
      duration: 100
    }

    expected_task_6 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(-day_seconds, :second),
      duration: 85
    }

    expected_task_7 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(10 * day_seconds, :second),
      duration: 100
    }

    expected_task_8 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(-10 * day_seconds, :second),
      duration: 85
    }

    expected_task_9 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(120 * day_seconds, :second),
      duration: 85
    }

    expected_task_10 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: NaiveDateTime.utc_now() |> NaiveDateTime.add(-120 * day_seconds, :second),
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
      sort_by: "task"
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
end
