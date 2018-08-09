defmodule Cli.RenderTest do
  @moduledoc false

  use ExUnit.Case

  test "retrieves the current shell width" do
    default_shell_width = 1
    assert Cli.Render.get_shell_width(default_shell_width) > 0 == true
  end

  test "converts timestamps to string" do
    {:ok, dt} = NaiveDateTime.from_iso8601("2018-12-21T01:02:03Z")
    assert Cli.Render.naive_date_time_to_string(dt) == "2018-12-21 01:02"

    {:ok, dt} = NaiveDateTime.from_iso8601("2018-03-04T00:00:03Z")
    assert Cli.Render.naive_date_time_to_string(dt) == "2018-03-04 00:00"

    {:ok, dt} = NaiveDateTime.from_iso8601("2000-01-01T00:01:02Z")
    assert Cli.Render.naive_date_time_to_string(dt) == "2000-01-01 00:01"
  end

  test "converts a list of tasks to table rows" do
    tasks = Cli.Fixtures.mock_tasks()

    expected_rows = [
      [
        Enum.at(tasks, 0).id,
        Enum.at(tasks, 0).task,
        Cli.Render.naive_date_time_to_string(Enum.at(tasks, 0).start),
        "#{Enum.at(tasks, 0).duration}m"
      ],
      [
        Enum.at(tasks, 1).id,
        Enum.at(tasks, 1).task,
        Cli.Render.naive_date_time_to_string(Enum.at(tasks, 1).start),
        "#{Enum.at(tasks, 1).duration}m"
      ],
      [
        Enum.at(tasks, 2).id,
        Enum.at(tasks, 2).task,
        Cli.Render.naive_date_time_to_string(Enum.at(tasks, 2).start),
        "#{Enum.at(tasks, 2).duration}m"
      ]
    ]

    assert Cli.Render.to_table_rows(tasks) == expected_rows
  end

  test "retrieves the current periods" do
    today = Date.utc_today()

    current_day = Date.to_string(today)

    current_week_monday =
      Date.add(
        today,
        -(Calendar.ISO.day_of_week(today.year, today.month, today.day) - 1)
      )

    current_week_days =
      Enum.map(0..6, fn week_day ->
        Date.to_string(Date.add(current_week_monday, week_day))
      end)

    current_month =
      "#{today.year}-#{today.month |> Integer.to_string() |> String.pad_leading(2, "0")}"

    assert Cli.Render.get_current_periods() == {current_day, current_week_days, current_month}
  end

  test "calculates the period range of a timestamp" do
    current_periods = Cli.Render.get_current_periods()

    day_seconds = 24 * 60 * 60

    today = NaiveDateTime.utc_now() |> Cli.Render.naive_date_time_to_string()
    assert Cli.Render.naive_date_time_to_period(today, current_periods) == :current_day

    today_p1 =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(day_seconds, :second)
      |> Cli.Render.naive_date_time_to_string()

    today_m1 =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-day_seconds, :second)
      |> Cli.Render.naive_date_time_to_string()

    today_p1 = Cli.Render.naive_date_time_to_period(today_p1, current_periods)
    today_m1 = Cli.Render.naive_date_time_to_period(today_m1, current_periods)
    assert today_p1 == :current_week || today_m1 == :current_week

    today = Date.utc_today()

    current_month =
      "#{today.year}-#{today.month |> Integer.to_string() |> String.pad_leading(2, "0")}"

    current_month_beginning = "#{current_month}-03T00:00:00"
    current_month_middle = "#{current_month}-15T00:00:00"
    current_month_end = "#{current_month}-25T00:00:00"

    current_month_beginning =
      Cli.Render.naive_date_time_to_period(current_month_beginning, current_periods)

    current_month_middle =
      Cli.Render.naive_date_time_to_period(current_month_middle, current_periods)

    current_month_end = Cli.Render.naive_date_time_to_period(current_month_end, current_periods)

    assert current_month_beginning == :current_month || current_month_middle == :current_month ||
             current_month_end == :current_month

    {:ok, past} = NaiveDateTime.from_iso8601("1999-12-21T01:02:03Z")
    past = Cli.Render.naive_date_time_to_string(past)
    assert Cli.Render.naive_date_time_to_period(past, current_periods) == :other

    {:ok, future} = NaiveDateTime.from_iso8601("2999-12-21T01:02:03Z")
    future = Cli.Render.naive_date_time_to_string(future)
    assert Cli.Render.naive_date_time_to_period(future, current_periods) == :other
  end

  test "creates a chart segment for an entry" do
    assert Cli.Render.entry_chart_segment("+", 3) == ["+", "+", "+"]
    assert Cli.Render.entry_chart_segment("+", 4) == ["+", "+", "+", "+"]
    assert Cli.Render.entry_chart_segment("+", 5) == ["+", "+", "+", "+", "+"]

    assert Cli.Render.coloured_entry_chart_segment("+", 3, :red) == [
             [[[[[] | "\e[31m"], "+"], "+"], "+"] | "\e[0m"
           ]
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

    {:ok, actual_table} =
      stream |> Aggregate.Tasks.as_sorted_list(query) |> Cli.Render.list_as_table()

    actual_table_size = actual_table |> String.split("\n", trim: true) |> length()

    assert actual_table_size == expected_table_size
  end

  test "converts aggregated tasks to a bar chart" do
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
      duration: 100
    }

    expected_task_6 = %Api.Task{
      id: UUID.uuid4(),
      task: List.duplicate("test", 120) |> Enum.join(),
      start: Enum.at(tasks, 0).start,
      duration: 85
    }

    stream =
      Cli.Fixtures.mock_tasks_stream(tasks ++ [expected_task_4, expected_task_5, expected_task_6])

    query = %Api.Query{
      from: Enum.at(tasks, 0).start,
      to: Enum.at(tasks, 0).start,
      sort_by: "task"
    }

    chart_header_size = 1
    expected_aggregated_tasks = 4
    expected_chart_size = expected_aggregated_tasks + chart_header_size

    {:ok, actual_chart} =
      stream
      |> Aggregate.Tasks.with_total_duration(query)
      |> Cli.Render.duration_aggregation_as_bar_chart()

    actual_chart_size = actual_chart |> String.split("\n", trim: true) |> length()

    assert actual_chart_size == expected_chart_size
  end
end
