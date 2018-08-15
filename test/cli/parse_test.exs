defmodule Cli.ParseTest do
  @moduledoc false

  use ExUnit.Case

  alias Cli.Parse, as: Parser

  @expected_task_args [
    task: :string,
    start_date: :string,
    start_time: :string,
    end_time: :string,
    duration: :string
  ]

  test "parses duration parameters" do
    assert Parser.parse_duration("30m") == {:ok, 30}
    assert Parser.parse_duration("5h") == {:ok, 300}
    assert Parser.parse_duration("0m") == {:ok, 0}
    assert Parser.parse_duration("0h") == {:ok, 0}
    assert Parser.parse_duration("") == {:error, "Invalid duration specified: []"}
    assert Parser.parse_duration("5") == {:error, "Invalid duration specified: [5]"}
    assert Parser.parse_duration("test") == {:error, "Invalid duration specified: [test]"}
  end

  test "parses time parameters" do
    expected_time = Time.utc_now()
    {:ok, :utc, actual_time} = Parser.parse_time("now")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.add(Time.utc_now(), 60, :second)
    {:ok, :utc, actual_time} = Parser.parse_time("now+1m")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.add(Time.utc_now(), -5 * 60, :second)
    {:ok, :utc, actual_time} = Parser.parse_time("now-5m")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.utc_now()
    {:ok, :utc, actual_time} = Parser.parse_time("now+0m")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.utc_now()
    {:ok, :utc, actual_time} = Parser.parse_time("now-0m")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.add(Time.utc_now(), 2 * 60 * 60, :second)
    {:ok, :utc, actual_time} = Parser.parse_time("now+2h")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.add(Time.utc_now(), -6 * 60 * 60, :second)
    {:ok, :utc, actual_time} = Parser.parse_time("now-6h")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.utc_now()
    {:ok, :utc, actual_time} = Parser.parse_time("now+0h")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.utc_now()
    {:ok, :utc, actual_time} = Parser.parse_time("now-0h")
    assert Time.diff(expected_time, actual_time, :second) == 0

    {:ok, expected_time} = Time.from_iso8601("12:34:56")
    {:ok, :local, actual_time} = Parser.parse_time("12:34:56")
    assert Time.diff(expected_time, actual_time, :second) == 0

    {:ok, expected_time} = Time.from_iso8601("12:34:00")
    {:ok, :local, actual_time} = Parser.parse_time("12:34")
    assert Time.diff(expected_time, actual_time, :second) == 0

    {:ok, expected_time} = Time.from_iso8601("12:34:00")
    {:ok, :local, actual_time} = Parser.parse_time("12:34:--")
    assert Time.diff(expected_time, actual_time, :second) == 0

    {:ok, expected_time} = Time.from_iso8601("12:34:00")
    {:ok, :local, actual_time} = Parser.parse_time("12:34.00")
    assert Time.diff(expected_time, actual_time, :second) == 0

    assert Parser.parse_time("12.34.56") == {:error, "Invalid time specified: [12.34.56]"}
  end

  test "parses date parameters" do
    expected_date = Date.utc_today()
    {:ok, actual_date} = Parser.parse_date("today")
    assert Date.diff(expected_date, actual_date) == 0

    expected_date = Date.add(Date.utc_today(), 1)
    {:ok, actual_date} = Parser.parse_date("today+1d")
    assert Date.diff(expected_date, actual_date) == 0

    expected_date = Date.add(Date.utc_today(), -3)
    {:ok, actual_date} = Parser.parse_date("today-3d")
    assert Date.diff(expected_date, actual_date) == 0

    expected_date = Date.utc_today()
    {:ok, actual_date} = Parser.parse_date("today+0d")
    assert Date.diff(expected_date, actual_date) == 0

    expected_date = Date.utc_today()
    {:ok, actual_date} = Parser.parse_date("today-0d")
    assert Date.diff(expected_date, actual_date) == 0

    {:ok, expected_date} = Date.from_iso8601("2018-12-21")
    {:ok, actual_date} = Parser.parse_date("2018-12-21")
    assert Date.diff(expected_date, actual_date) == 0

    assert Parser.parse_date("2018.12.21") == {:error, "Invalid date specified: [2018.12.21]"}

    assert Parser.parse_date("2018-31-02") == {:error, :invalid_date}
  end

  test "parses task parameters" do
    assert Parser.parse_task("some-task") == {:ok, "some-task"}
    assert Parser.parse_task("t") == {:ok, "t"}
    assert Parser.parse_task("") == {:error, "No task specified"}
    assert Parser.parse_task(nil) == {:error, "No task specified"}
  end

  test "parses arguments as key=value pairs" do
    assert Parser.parse_as_kv(
             @expected_task_args,
             [
               "task=some-task",
               "start-date=today+1d"
             ]
           ) == [
             task: "some-task",
             start_date: "today+1d"
           ]

    assert Parser.parse_as_kv(
             @expected_task_args,
             [
               "task=some-task",
               "start-date=today",
               "start-time=now-10m",
               "end-time=now"
             ]
           ) == [
             task: "some-task",
             start_date: "today",
             start_time: "now-10m",
             end_time: "now"
           ]

    assert Parser.parse_as_kv(
             @expected_task_args,
             [
               "task=some-task",
               "start-date=today",
               "start-time=now-10m",
               "duration=2h"
             ]
           ) == [
             task: "some-task",
             start_date: "today",
             start_time: "now-10m",
             duration: "2h"
           ]

    assert Parser.parse_as_kv(
             @expected_task_args,
             [
               "task=some-task",
               "start-date=today+1d",
               "some-param=test",
               "other=42"
             ]
           ) == [
             task: "some-task",
             start_date: "today+1d"
           ]

    assert Parser.parse_as_kv(
             @expected_task_args,
             [
               "some-task=some-task",
               "some-start-date=today",
               "some-start-time=now-10m",
               "some-end-time=now"
             ]
           ) == []

    assert Parser.parse_as_kv(@expected_task_args, []) == []
  end

  test "parses arguments as positional parameters" do
    assert Parser.parse_as_positional(
             @expected_task_args,
             [
               "some-task",
               "today+1d"
             ]
           ) == [
             task: "some-task",
             start_date: "today+1d"
           ]

    assert Parser.parse_as_positional(
             @expected_task_args,
             [
               "some-task",
               "today",
               "now-10m",
               "now"
             ]
           ) == [
             task: "some-task",
             start_date: "today",
             start_time: "now-10m",
             end_time: "now"
           ]

    assert Parser.parse_as_positional(
             @expected_task_args,
             [
               "some-task",
               "today",
               "now-10m",
               "2h"
             ]
           ) == [
             task: "some-task",
             start_date: "today",
             start_time: "now-10m",
             # valid positional param but invalid logical param
             end_time: "2h"
           ]

    assert Parser.parse_as_positional(
             @expected_task_args,
             [
               "some-task",
               "today+1d",
               "test",
               "42"
             ]
           ) == [
             task: "some-task",
             start_date: "today+1d",
             # valid positional param but invalid logical param
             start_time: "test",
             # valid positional param but invalid logical param
             end_time: "42"
           ]

    assert Parser.parse_as_positional(@expected_task_args, []) == []
  end

  test "parses arguments as options" do
    assert Parser.parse_as_options(
             @expected_task_args,
             [
               "--task",
               "some-task",
               "--start-date",
               "today+1d"
             ]
           ) == [
             task: "some-task",
             start_date: "today+1d"
           ]

    assert Parser.parse_as_options(
             @expected_task_args,
             [
               "--task",
               "some-task",
               "--start-date",
               "today",
               "--start-time",
               "now-10m",
               "--end-time",
               "now"
             ]
           ) == [
             task: "some-task",
             start_date: "today",
             start_time: "now-10m",
             end_time: "now"
           ]

    assert Parser.parse_as_options(
             @expected_task_args,
             [
               "--task",
               "some-task",
               "--start-date",
               "today",
               "--start-time",
               "now-10m",
               "--duration",
               "2h"
             ]
           ) == [
             task: "some-task",
             start_date: "today",
             start_time: "now-10m",
             duration: "2h"
           ]

    assert Parser.parse_as_options(
             @expected_task_args,
             [
               "--task",
               "some-task",
               "--start-date",
               "today+1d",
               "--some-param",
               "test",
               "--other",
               "42"
             ]
           ) == [
             task: "some-task",
             start_date: "today+1d"
           ]

    assert Parser.parse_as_options(
             @expected_task_args,
             [
               "--some-task",
               "some-task",
               "--some-start-date",
               "today",
               "--some-start-time",
               "now-10m",
               "--some-end-time",
               "now"
             ]
           ) == []

    assert Parser.parse_as_options(@expected_task_args, []) == []
  end

  test "converts date/time (local) strings to timestamps (UTC)" do
    {:ok, expected_date_time} = NaiveDateTime.from_iso8601("2018-12-21T21:30:00")
    {:ok, actual_date_time} = Parser.from_local_time_zone("2018-12-21", "21:30:00", :utc)
    assert expected_date_time == actual_date_time

    {:error, error} = Parser.from_local_time_zone("2018-12-21", "21:30", :utc)
    assert error == :invalid_format

    {:ok, expected_date_time} = NaiveDateTime.from_iso8601("2018-12-21T21:30:00")

    [expected_date_time] =
      expected_date_time
      |> NaiveDateTime.to_erl()
      |> :calendar.local_time_to_universal_time_dst()
      |> Enum.map(fn dt -> NaiveDateTime.from_erl!(dt) end)

    {:ok, actual_date_time} = Parser.from_local_time_zone("2018-12-21", "21:30:00", :local)
    assert expected_date_time == actual_date_time

    # test result is dependant on the local user's time zone
    {:ok, expected_date_time} = NaiveDateTime.from_iso8601("2018-03-25T02:33:00")

    case Parser.from_local_time_zone("2018-03-25", "02:33:00", :local) do
      {:ok, actual_date_time} ->
        [expected_date_time] =
          expected_date_time
          |> NaiveDateTime.to_erl()
          |> :calendar.local_time_to_universal_time_dst()
          |> Enum.map(fn dt -> NaiveDateTime.from_erl!(dt) end)

        assert expected_date_time == actual_date_time

      {:error, error} ->
        assert error == "Period skipped due to switching to DST"
    end

    # test result is dependant on the local user's time zone
    {:ok, expected_date_time} = NaiveDateTime.from_iso8601("2018-10-28T02:33:00")

    expected_date_time =
      expected_date_time
      |> NaiveDateTime.to_erl()
      |> :calendar.local_time_to_universal_time_dst()
      |> Enum.map(fn dt -> NaiveDateTime.from_erl!(dt) end)

    {:ok, actual_date_time} = Parser.from_local_time_zone("2018-10-28", "02:33:00", :local)

    case expected_date_time do
      [] -> assert true
      [expected_date_time] -> assert expected_date_time == actual_date_time
      [_, expected_date_time] -> assert expected_date_time == actual_date_time
    end
  end

  test "generates duration from parsed parameters" do
    start_date = "2018-12-21"

    parsed_args = [end_time: "now+10m"]
    {:ok, :utc, start_time} = Parser.parse_time("now")
    {:ok, start_time} = Parser.from_local_time_zone(start_date, start_time, :utc)
    expected_duration = 10
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time, start_date)
    assert expected_duration == actual_duration

    parsed_args = [end_time: "21:43"]
    {:ok, :local, start_time} = Parser.parse_time("21:30")
    {:ok, start_time} = Parser.from_local_time_zone(start_date, start_time, :local)
    expected_duration = 13
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time, start_date)
    assert expected_duration == actual_duration

    parsed_args = [end_time: "now+1h"]
    {:ok, :utc, start_time} = Parser.parse_time("now+45m")
    {:ok, start_time} = Parser.from_local_time_zone(start_date, start_time, :utc)
    expected_duration = 15
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time, start_date)
    assert expected_duration == actual_duration

    parsed_args = [end_time: "now+23h"]
    {:ok, :utc, start_time} = Parser.parse_time("now+5h")
    {:ok, start_time} = Parser.from_local_time_zone(start_date, start_time, :utc)
    expected_duration = 18 * 60
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time, start_date)
    assert expected_duration == actual_duration

    parsed_args = [end_time: "now"]
    {:ok, :utc, start_time} = Parser.parse_time("now")
    {:ok, start_time} = Parser.from_local_time_zone(start_date, start_time, :utc)

    assert Parser.duration_from_parsed_args(parsed_args, start_time, start_date) ==
             {:error, "The specified start and end times are the same"}

    parsed_args = [end_time: "tomorrow"]
    {:ok, :utc, start_time} = Parser.parse_time("now")

    assert Parser.duration_from_parsed_args(parsed_args, start_time, start_date) ==
             {:error, "Invalid time specified: [tomorrow]"}

    parsed_args = [end_time: "now-10m"]
    {:ok, :utc, start_time} = Parser.parse_time("now")
    {:ok, start_time} = Parser.from_local_time_zone(start_date, start_time, :utc)
    expected_duration = 24 * 60 - 10
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time, start_date)
    assert expected_duration == actual_duration

    parsed_args = [end_time: "21:30"]
    {:ok, :local, start_time} = Parser.parse_time("21:43")
    {:ok, start_time} = Parser.from_local_time_zone(start_date, start_time, :local)
    expected_duration = 24 * 60 - 13
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time, start_date)
    assert expected_duration == actual_duration

    parsed_args = [duration: "10m"]
    {:ok, :utc, start_time} = Parser.parse_time("now")
    {:ok, start_time} = Parser.from_local_time_zone(start_date, start_time, :utc)
    expected_duration = 10
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time, start_date)
    assert expected_duration == actual_duration

    parsed_args = [duration: "1h"]
    {:ok, :utc, start_time} = Parser.parse_time("now+45m")
    {:ok, start_time} = Parser.from_local_time_zone(start_date, start_time, :utc)
    expected_duration = 60
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time, start_date)
    assert expected_duration == actual_duration

    parsed_args = [duration: "0m"]
    {:ok, :utc, start_time} = Parser.parse_time("now+5h")
    {:ok, start_time} = Parser.from_local_time_zone(start_date, start_time, :utc)
    {:error, message} = Parser.duration_from_parsed_args(parsed_args, start_time, start_date)
    assert message == "Task duration cannot be [0]"

    parsed_args = []
    {:ok, :utc, start_time} = Parser.parse_time("now+5h")
    {:ok, start_time} = Parser.from_local_time_zone(start_date, start_time, :utc)
    {:error, message} = Parser.duration_from_parsed_args(parsed_args, start_time, start_date)
    assert message == "No task duration specified"
  end

  test "parses arguments into tasks" do
    args = [
      "--task",
      "test-task",
      "--start-date",
      "2018-12-21",
      "--start-time",
      "21:35",
      "--end-time",
      "23:00"
    ]

    expected_start = local_to_utc_timestamp("2018-12-21T21:35:00Z")

    expected_task = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task",
      start: expected_start,
      duration: 85
    }

    {:ok, actual_task} = Parser.args_to_task(args)
    assert expected_task.task == actual_task.task
    assert expected_task.start == actual_task.start
    assert expected_task.duration == actual_task.duration

    args = [
      "task=test-task",
      "start-date=2018-12-21",
      "start-time=21:35",
      "end-time=23:00"
    ]

    expected_start = local_to_utc_timestamp("2018-12-21T21:35:00Z")

    expected_task = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task",
      start: expected_start,
      duration: 85
    }

    {:ok, actual_task} = Parser.args_to_task(args)
    assert expected_task.task == actual_task.task
    assert expected_task.start == actual_task.start
    assert expected_task.duration == actual_task.duration

    args = [
      "test-task",
      "2018-12-21",
      "21:35",
      "23:00"
    ]

    expected_start = local_to_utc_timestamp("2018-12-21T21:35:00Z")

    expected_task = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task",
      start: expected_start,
      duration: 85
    }

    {:ok, actual_task} = Parser.args_to_task(args)
    assert expected_task.task == actual_task.task
    assert expected_task.start == actual_task.start
    assert expected_task.duration == actual_task.duration

    args = [
      "test-task",
      "2018-12-21",
      "21:35",
      "85m"
    ]

    expected_start = local_to_utc_timestamp("2018-12-21T21:35:00Z")

    expected_task = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task",
      start: expected_start,
      duration: 85
    }

    {:ok, actual_task} = Parser.args_to_task(args)
    assert expected_task.task == actual_task.task
    assert expected_task.start == actual_task.start
    assert expected_task.duration == actual_task.duration

    assert Parser.args_to_task(["a=b"]) == {:error, "No task specified"}

    assert Parser.args_to_task([]) == {:error, "No arguments specified"}
  end

  test "parses arguments into queries" do
    args = [
      "--from",
      "2018-12-21",
      "--to",
      "2018-12-22"
    ]

    {:ok, expected_from} = NaiveDateTime.from_iso8601("2018-12-21T00:00:00")
    {:ok, expected_to} = NaiveDateTime.from_iso8601("2018-12-22T23:59:59")

    expected_query = %Api.Query{
      from: expected_from,
      to: expected_to,
      sort_by: "start",
      order: "desc"
    }

    {:ok, actual_query} = Parser.args_to_query(args)
    assert expected_query == actual_query

    args = [
      "--from",
      "2018-12-21",
      "--to",
      "2018-12-22",
      "--sort-by",
      "task"
    ]

    {:ok, expected_from} = NaiveDateTime.from_iso8601("2018-12-21T00:00:00")
    {:ok, expected_to} = NaiveDateTime.from_iso8601("2018-12-22T23:59:59")

    expected_query = %Api.Query{
      from: expected_from,
      to: expected_to,
      sort_by: "task",
      order: "desc"
    }

    {:ok, actual_query} = Parser.args_to_query(args)
    assert expected_query == actual_query

    args = [
      "from=2018-12-21",
      "to=2018-12-22",
      "sort-by=duration"
    ]

    {:ok, expected_from} = NaiveDateTime.from_iso8601("2018-12-21T00:00:00")
    {:ok, expected_to} = NaiveDateTime.from_iso8601("2018-12-22T23:59:59")

    expected_query = %Api.Query{
      from: expected_from,
      to: expected_to,
      sort_by: "duration",
      order: "desc"
    }

    {:ok, actual_query} = Parser.args_to_query(args)
    assert expected_query == actual_query

    args = [
      "from=2018-12-21",
      "to=2018-12-22",
      "sort-by=duration",
      "order=asc"
    ]

    {:ok, expected_from} = NaiveDateTime.from_iso8601("2018-12-21T00:00:00")
    {:ok, expected_to} = NaiveDateTime.from_iso8601("2018-12-22T23:59:59")

    expected_query = %Api.Query{
      from: expected_from,
      to: expected_to,
      sort_by: "duration",
      order: "asc"
    }

    {:ok, actual_query} = Parser.args_to_query(args)
    assert expected_query == actual_query

    args = [
      "2018-12-21",
      "2018-12-22",
      "id"
    ]

    {:ok, expected_from} = NaiveDateTime.from_iso8601("2018-12-21T00:00:00")
    {:ok, expected_to} = NaiveDateTime.from_iso8601("2018-12-22T23:59:59")

    expected_query = %Api.Query{
      from: expected_from,
      to: expected_to,
      sort_by: "id",
      order: "desc"
    }

    {:ok, actual_query} = Parser.args_to_query(args)
    assert expected_query == actual_query

    args = ["a=b"]

    {:ok, expected_from} = NaiveDateTime.from_iso8601("#{Date.utc_today()}T00:00:00")
    {:ok, expected_to} = NaiveDateTime.from_iso8601("#{Date.utc_today()}T23:59:59")

    expected_query = %Api.Query{
      from: expected_from,
      to: expected_to,
      sort_by: "start",
      order: "desc"
    }

    {:ok, actual_query} = Parser.args_to_query(args)
    assert expected_query == actual_query

    args = []

    {:ok, expected_from} = NaiveDateTime.from_iso8601("#{Date.utc_today()}T00:00:00")
    {:ok, expected_to} = NaiveDateTime.from_iso8601("#{Date.utc_today()}T23:59:59")

    expected_query = %Api.Query{
      from: expected_from,
      to: expected_to,
      sort_by: "start",
      order: "desc"
    }

    {:ok, actual_query} = Parser.args_to_query(args)
    assert expected_query == actual_query
  end

  test "parses arguments into task updates" do
    args = [
      "--task",
      "test-task"
    ]

    expected_update = %Api.TaskUpdate{
      task: "test-task",
      start: nil,
      duration: nil
    }

    {:ok, actual_update} = Parser.args_to_task_update(args)
    assert expected_update.task == actual_update.task
    assert expected_update.start == actual_update.start
    assert expected_update.duration == actual_update.duration

    args = [
      "--start-date",
      "2018-12-21",
      "--start-time",
      "21:35"
    ]

    expected_start = local_to_utc_timestamp("2018-12-21T21:35:00Z")

    expected_update = %Api.TaskUpdate{
      task: nil,
      start: expected_start,
      duration: nil
    }

    {:ok, actual_update} = Parser.args_to_task_update(args)
    assert expected_update.task == actual_update.task
    assert expected_update.start == actual_update.start
    assert expected_update.duration == actual_update.duration

    args = [
      "--duration",
      "2h"
    ]

    expected_update = %Api.TaskUpdate{
      task: nil,
      start: nil,
      duration: 120
    }

    {:ok, actual_update} = Parser.args_to_task_update(args)
    assert expected_update.task == actual_update.task
    assert expected_update.start == actual_update.start
    assert expected_update.duration == actual_update.duration

    args = [
      "--task",
      "test-task",
      "--start-date",
      "2018-12-21",
      "--start-time",
      "21:35",
      "--duration",
      "15m"
    ]

    expected_start = local_to_utc_timestamp("2018-12-21T21:35:00Z")

    expected_update = %Api.TaskUpdate{
      task: "test-task",
      start: expected_start,
      duration: 15
    }

    {:ok, actual_update} = Parser.args_to_task_update(args)
    assert expected_update.task == actual_update.task
    assert expected_update.start == actual_update.start
    assert expected_update.duration == actual_update.duration

    args = [
      "task=test-task",
      "start-date=2018-12-21",
      "start-time=21:35",
      "duration=15m"
    ]

    expected_start = local_to_utc_timestamp("2018-12-21T21:35:00Z")

    expected_update = %Api.TaskUpdate{
      task: "test-task",
      start: expected_start,
      duration: 15
    }

    {:ok, actual_update} = Parser.args_to_task_update(args)
    assert expected_update.task == actual_update.task
    assert expected_update.start == actual_update.start
    assert expected_update.duration == actual_update.duration

    args = [
      "task=test-task",
      "start-date=2018-12-21",
      "start-time=21:35",
      "duration=0m"
    ]

    assert Parser.args_to_task_update(args) == {:error, "Task duration cannot be [0]"}

    args = [
      "task=test-task",
      "start-date=2018-12-21",
      "start-time=21:35",
      "duration=15s"
    ]

    assert Parser.args_to_task_update(args) == {:error, "Invalid duration specified: [15s]"}

    assert Parser.args_to_task_update(["start-date=2018-12-21"]) ==
             {:error, "No expected or valid arguments specified"}

    assert Parser.args_to_task_update(["a=b"]) == {:error, "No or unparsable arguments specified"}

    assert Parser.args_to_task_update([]) == {:error, "No or unparsable arguments specified"}
  end

  test "parse arguments into application options" do
    args = ["--verbose"]
    assert Parser.extract_application_options(args) == {[verbose: true], []}

    args = ["--verbose", "--config", "some-file.conf"]

    assert Parser.extract_application_options(args) ==
             {[verbose: true, config: "some-file.conf"], []}

    args = ["--config", "some-file.conf"]
    assert Parser.extract_application_options(args) == {[config: "some-file.conf"], []}

    args = ["some-file.conf"]
    assert Parser.extract_application_options(args) == {[], ["some-file.conf"]}

    args = ["param-1", "--config", "some-file.conf", "param-2"]

    assert Parser.extract_application_options(args) ==
             {[config: "some-file.conf"], ["param-1", "param-2"]}

    args = ["param-1", "--verbose", "--config", "some-file.conf"]

    assert Parser.extract_application_options(args) ==
             {[verbose: true, config: "some-file.conf"], ["param-1"]}

    args = ["param-1", "--verbose", "param-2", "param-3", "--config", "some-file.conf"]

    assert Parser.extract_application_options(args) ==
             {[verbose: true, config: "some-file.conf"], ["param-1", "param-2", "param-3"]}

    args = ["param-1", "--verbose", "param-2", "param-3", "--config", "some-file.conf", "param-4"]

    assert Parser.extract_application_options(args) ==
             {[verbose: true, config: "some-file.conf"],
              ["param-1", "param-2", "param-3", "param-4"]}

    args = [
      "--param-1",
      "--verbose",
      "param-2",
      "param-3",
      "--config",
      "some-file.conf",
      "param-4"
    ]

    assert Parser.extract_application_options(args) ==
             {[verbose: true, config: "some-file.conf"],
              ["--param-1", "param-2", "param-3", "param-4"]}

    args = [
      "param-1",
      "--verbose",
      "--param-2",
      "value-2",
      "--config",
      "some-file.conf",
      "param-4"
    ]

    assert Parser.extract_application_options(args) ==
             {[verbose: true, config: "some-file.conf"],
              ["param-1", "--param-2", "value-2", "param-4"]}

    args = [
      "param-1",
      "--verbose",
      "--param-2",
      "value-2",
      "--config",
      "some-file.conf",
      "--param-4"
    ]

    assert Parser.extract_application_options(args) ==
             {[verbose: true, config: "some-file.conf"],
              ["param-1", "--param-2", "value-2", "--param-4"]}

    args = [
      "--param-1",
      "--verbose",
      "--param-2",
      "value-2",
      "--config",
      "some-file.conf",
      "--param-4"
    ]

    assert Parser.extract_application_options(args) ==
             {[verbose: true, config: "some-file.conf"],
              ["--param-1", "--param-2", "value-2", "--param-4"]}

    args = []
    assert Parser.extract_application_options(args) == {[], []}
  end

  defp local_to_utc_timestamp(dt) do
    {:ok, dt} = NaiveDateTime.from_iso8601(dt)
    [dt] = dt |> NaiveDateTime.to_erl() |> :calendar.local_time_to_universal_time_dst()
    dt |> NaiveDateTime.from_erl!()
  end
end
