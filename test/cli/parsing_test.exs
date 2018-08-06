defmodule Cli.ParsingTest do
  @moduledoc false
  use ExUnit.Case

  alias Cli.Parsing, as: Parser

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
    {:ok, actual_time} = Parser.parse_time("now")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.add(Time.utc_now(), 60, :second)
    {:ok, actual_time} = Parser.parse_time("now+1m")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.add(Time.utc_now(), -5 * 60, :second)
    {:ok, actual_time} = Parser.parse_time("now-5m")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.utc_now()
    {:ok, actual_time} = Parser.parse_time("now+0m")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.utc_now()
    {:ok, actual_time} = Parser.parse_time("now-0m")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.add(Time.utc_now(), 2 * 60 * 60, :second)
    {:ok, actual_time} = Parser.parse_time("now+2h")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.add(Time.utc_now(), -6 * 60 * 60, :second)
    {:ok, actual_time} = Parser.parse_time("now-6h")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.utc_now()
    {:ok, actual_time} = Parser.parse_time("now+0h")
    assert Time.diff(expected_time, actual_time, :second) == 0

    expected_time = Time.utc_now()
    {:ok, actual_time} = Parser.parse_time("now-0h")
    assert Time.diff(expected_time, actual_time, :second) == 0

    {:ok, expected_time} = Time.from_iso8601("12:34:56")
    {:ok, actual_time} = Parser.parse_time("12:34:56")
    assert Time.diff(expected_time, actual_time, :second) == 0

    {:ok, expected_time} = Time.from_iso8601("12:34:00")
    {:ok, actual_time} = Parser.parse_time("12:34")
    assert Time.diff(expected_time, actual_time, :second) == 0

    {:ok, expected_time} = Time.from_iso8601("12:34:00")
    {:ok, actual_time} = Parser.parse_time("12:34:--")
    assert Time.diff(expected_time, actual_time, :second) == 0

    {:ok, expected_time} = Time.from_iso8601("12:34:00")
    {:ok, actual_time} = Parser.parse_time("12:34.00")
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
  end

  test "parses arguments as key=value pairs" do
    assert Parser.parse_as_kv([
             "task=some-task",
             "start-date=today+1d"
           ]) == [
             task: "some-task",
             start_date: "today+1d"
           ]

    assert Parser.parse_as_kv([
             "task=some-task",
             "start-date=today",
             "start-time=now-10m",
             "end-time=now"
           ]) == [
             task: "some-task",
             start_date: "today",
             start_time: "now-10m",
             end_time: "now"
           ]

    assert Parser.parse_as_kv([
             "task=some-task",
             "start-date=today",
             "start-time=now-10m",
             "duration=2h"
           ]) == [
             task: "some-task",
             start_date: "today",
             start_time: "now-10m",
             duration: "2h"
           ]

    assert Parser.parse_as_kv([
             "task=some-task",
             "start-date=today+1d",
             "some-param=test",
             "other=42"
           ]) == [
             task: "some-task",
             start_date: "today+1d"
           ]

    assert Parser.parse_as_kv([
             "some-task=some-task",
             "some-start-date=today",
             "some-start-time=now-10m",
             "some-end-time=now"
           ]) == []

    assert Parser.parse_as_kv([]) == []
  end

  test "parses arguments as positional parameters" do
    assert Parser.parse_as_positional([
             "some-task",
             "today+1d"
           ]) == [
             task: "some-task",
             start_date: "today+1d"
           ]

    assert Parser.parse_as_positional([
             "some-task",
             "today",
             "now-10m",
             "now"
           ]) == [
             task: "some-task",
             start_date: "today",
             start_time: "now-10m",
             end_time: "now"
           ]

    assert Parser.parse_as_positional([
             "some-task",
             "today",
             "now-10m",
             "2h"
           ]) == [
             duration: "2h",
             task: "some-task",
             start_date: "today",
             start_time: "now-10m"
           ]

    assert Parser.parse_as_positional([
             "some-task",
             "today+1d",
             "test",
             "42"
           ]) == [
             task: "some-task",
             start_date: "today+1d",
             # valid positional param but invalid logical param
             start_time: "test",
             # valid positional param but invalid logical param
             end_time: "42"
           ]

    assert Parser.parse_as_positional([]) == []
  end

  test "parses arguments as options" do
    assert Parser.parse_as_options([
             "--task",
             "some-task",
             "--start-date",
             "today+1d"
           ]) == [
             task: "some-task",
             start_date: "today+1d"
           ]

    assert Parser.parse_as_options([
             "--task",
             "some-task",
             "--start-date",
             "today",
             "--start-time",
             "now-10m",
             "--end-time",
             "now"
           ]) == [
             task: "some-task",
             start_date: "today",
             start_time: "now-10m",
             end_time: "now"
           ]

    assert Parser.parse_as_options([
             "--task",
             "some-task",
             "--start-date",
             "today",
             "--start-time",
             "now-10m",
             "--duration",
             "2h"
           ]) == [
             task: "some-task",
             start_date: "today",
             start_time: "now-10m",
             duration: "2h"
           ]

    assert Parser.parse_as_options([
             "--task",
             "some-task",
             "--start-date",
             "today+1d",
             "--some-param",
             "test",
             "--other",
             "42"
           ]) == [
             task: "some-task",
             start_date: "today+1d"
           ]

    assert Parser.parse_as_options([
             "--some-task",
             "some-task",
             "--some-start-date",
             "today",
             "--some-start-time",
             "now-10m",
             "--some-end-time",
             "now"
           ]) == []

    assert Parser.parse_as_options([]) == []
  end

  test "generates duration from parsed parameters" do
    parsed_args = [end_time: "now+10m"]
    {:ok, start_time} = Parser.parse_time("now")
    expected_duration = 10
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time)
    assert expected_duration == actual_duration

    parsed_args = [end_time: "now+1h"]
    {:ok, start_time} = Parser.parse_time("now+45m")
    expected_duration = 15
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time)
    assert expected_duration == actual_duration

    parsed_args = [end_time: "now+23h"]
    {:ok, start_time} = Parser.parse_time("now+5h")
    expected_duration = 18 * 60
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time)
    assert expected_duration == actual_duration

    parsed_args = [end_time: "now"]
    {:ok, start_time} = Parser.parse_time("now")

    assert Parser.duration_from_parsed_args(parsed_args, start_time) ==
             {:error, "The specified start and end times are the same"}

    parsed_args = [end_time: "tomorrow"]
    {:ok, start_time} = Parser.parse_time("now")

    assert Parser.duration_from_parsed_args(parsed_args, start_time) ==
             {:error, "Failed to parse end time: [Invalid time specified: [tomorrow]]"}

    parsed_args = [end_time: "now-10m"]
    {:ok, start_time} = Parser.parse_time("now")
    expected_duration = 24 * 60 - 10
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time)
    assert expected_duration == actual_duration

    parsed_args = [duration: "10m"]
    {:ok, start_time} = Parser.parse_time("now")
    expected_duration = 10
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time)
    assert expected_duration == actual_duration

    parsed_args = [duration: "1h"]
    {:ok, start_time} = Parser.parse_time("now+45m")
    expected_duration = 60
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time)
    assert expected_duration == actual_duration

    parsed_args = []
    {:ok, start_time} = Parser.parse_time("now+5h")
    expected_duration = 0
    {:ok, actual_duration} = Parser.duration_from_parsed_args(parsed_args, start_time)
    assert expected_duration == actual_duration
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

    {:ok, expected_start, 0} = DateTime.from_iso8601("2018-12-21T21:35:00Z")

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

    {:ok, expected_start, 0} = DateTime.from_iso8601("2018-12-21T21:35:00Z")

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

    {:ok, expected_start, 0} = DateTime.from_iso8601("2018-12-21T21:35:00Z")

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

    {:ok, expected_start, 0} = DateTime.from_iso8601("2018-12-21T21:35:00Z")

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

    assert Parser.args_to_task([]) == {:error, "No arguments specified"}
  end
end
