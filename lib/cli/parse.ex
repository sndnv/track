defmodule Cli.Parse do
  @moduledoc """
  Module used for parsing user input.
  """

  require Logger

  @day_minutes 24 * 60

  @application_options [verbose: :boolean, config: :string]

  @doc """
  Extracts options from the supplied arguments that are not task/query related.

  The supported options are:
  - `:verbose` - for enabling extra logging
  - `:config` - for supplying a custom config file

  The function returns the remaining arguments without the above options.
  """

  def extract_application_options(args) do
    {options, _, _} = OptionParser.parse(args, strict: @application_options)

    parsed_args = Enum.flat_map(options, fn {k, v} -> ["--#{Atom.to_string(k)}", v] end)
    remaining_args = Enum.reject(args, fn arg -> Enum.member?(parsed_args, arg) end)

    {options, remaining_args}
  end

  @expected_update_args [
    task: :string,
    start_date: :string,
    start_time: :string,
    duration: :string
  ]

  @doc """
  Generates a new `Api.TaskUpdate` object from the supplied arguments.
  """

  def args_to_task_update(args) do
    parsed =
      case args do
        [head | _] ->
          cond do
            String.starts_with?(head, "--") ->
              parse_as_options(@expected_update_args, args)

            String.contains?(head, "=") ->
              parse_as_kv(@expected_update_args, args)

            true ->
              # positional arguments are not supported
              []
          end

        [] ->
          []
      end

    case parsed do
      [_ | _] ->
        task =
          if parsed[:task] do
            parse_task(parsed[:task])
          else
            {:ok, nil}
          end

        start_utc =
          if parsed[:start_date] && parsed[:start_time] do
            with {:ok, start_date} <- parse_date(parsed[:start_date]),
                 {:ok, time_type, start_time} <- parse_time(parsed[:start_time]),
                 {:ok, start_utc} <- from_local_time_zone(start_date, start_time, time_type) do
              {:ok, start_utc}
            end
          else
            {:ok, nil}
          end

        duration =
          if parsed[:duration] do
            case parse_duration(parsed[:duration]) do
              {:ok, parsed_duration} when parsed_duration > 0 -> {:ok, parsed_duration}
              {:ok, parsed_duration} -> {:error, "Task duration cannot be [#{parsed_duration}]"}
              error -> error
            end
          else
            {:ok, nil}
          end

        with {:ok, task} <- task,
             {:ok, start_utc} <- start_utc,
             {:ok, duration} <- duration do
          if task || start_utc || duration do
            {
              :ok,
              %Api.TaskUpdate{
                task: task,
                start: start_utc,
                duration: duration
              }
            }
          else
            {:error, "No expected or valid arguments specified"}
          end
        end

      [] ->
        {:error, "No or unparsable arguments specified"}
    end
  end

  @expected_query_args [
    from: :string,
    to: :string,
    sort_by: :string,
    order: :string
  ]

  @doc """
  Generates a new `Api.Query` object from the supplied arguments.
  """

  def args_to_query(args) do
    parsed =
      case args do
        [head | _] ->
          cond do
            String.starts_with?(head, "--") -> parse_as_options(@expected_query_args, args)
            String.contains?(head, "=") -> parse_as_kv(@expected_query_args, args)
            true -> parse_as_positional(@expected_query_args, args)
          end

        [] ->
          # uses defaults
          []
      end

    with {:ok, from_date} <- parse_date(Keyword.get(parsed, :from, "today")),
         {:ok, to_date} <- parse_date(Keyword.get(parsed, :to, "today")),
         {:ok, from} <- NaiveDateTime.from_iso8601("#{from_date}T00:00:00"),
         {:ok, to} <- NaiveDateTime.from_iso8601("#{to_date}T23:59:59"),
         sort_by <- Keyword.get(parsed, :sort_by, "start"),
         order <- Keyword.get(parsed, :order, "desc") do
      {
        :ok,
        %Api.Query{
          from: from,
          to: to,
          sort_by: sort_by,
          order: order
        }
      }
    end
  end

  @expected_task_args [
    task: :string,
    start_date: :string,
    start_time: :string,
    end_time: :string,
    duration: :string
  ]

  @doc """
  Generates a new `Api.Task` object from the supplied arguments.
  """

  def args_to_task(args) do
    case args do
      [head | _] ->
        parsed =
          cond do
            String.starts_with?(head, "--") ->
              parse_as_options(@expected_task_args, args)

            String.contains?(head, "=") ->
              parse_as_kv(@expected_task_args, args)

            true ->
              parsed = parse_as_positional(@expected_task_args, args)

              case parse_duration(Keyword.get(parsed, :end_time, "")) do
                {:ok, _} ->
                  parsed |> Keyword.delete(:end_time) |> Keyword.put(:duration, parsed[:end_time])

                {:error, _} ->
                  parsed
              end
          end

        with {:ok, task} <- parse_task(parsed[:task]),
             {:ok, start_date} <- parse_date(Keyword.get(parsed, :start_date, "today")),
             {:ok, time_type, start_time} <- parse_time(Keyword.get(parsed, :start_time, "now")),
             {:ok, start_utc} <- from_local_time_zone(start_date, start_time, time_type),
             {:ok, duration} <- duration_from_parsed_args(parsed, start_utc, start_date) do
          {
            :ok,
            %Api.Task{
              id: UUID.uuid4(),
              task: task,
              start: start_utc,
              duration: duration
            }
          }
        end

      [] ->
        {:error, "No arguments specified"}
    end
  end

  @doc """
  Calculates a task's duration based on the supplied parsed arguments.

  A duration of 0 is considered to be an error.
  """

  def duration_from_parsed_args(parsed_args, start_utc, start_date) do
    cond do
      parsed_args[:duration] ->
        with {:ok, duration} <- parse_duration(parsed_args[:duration]) do
          if duration > 0 do
            {:ok, duration}
          else
            {:error, "Task duration cannot be [#{duration}]"}
          end
        end

      parsed_args[:end_time] ->
        with {:ok, end_time_type, end_time} <- parse_time(parsed_args[:end_time]),
             {:ok, end_utc} <- from_local_time_zone(start_date, end_time, end_time_type) do
          case NaiveDateTime.compare(
                 NaiveDateTime.truncate(end_utc, :second),
                 NaiveDateTime.truncate(start_utc, :second)
               ) do
            :lt ->
              {:ok, div(NaiveDateTime.diff(end_utc, start_utc, :second), 60) + @day_minutes}

            :gt ->
              {:ok, div(NaiveDateTime.diff(end_utc, start_utc, :second), 60)}

            :eq ->
              {:error, "The specified start and end times are the same"}
          end
        end

      true ->
        {:error, "No task duration specified"}
    end
  end

  @doc """
  Converts the supplied date and time strings to UTC, if needed.

  > For local-to-utc conversions, daylight savings time (DST) can result in two or no timestamps being generated.
  > If the supplied date/time cannot be represented due to DST, an error is returned.
  > If the supplied date/time results in two timestamps, only the non-DST timestamp is returned.
  > In either case, a warning will be emitted.
  """

  def from_local_time_zone(date, time, time_type) do
    case NaiveDateTime.from_iso8601("#{date}T#{time}") do
      {:ok, time} ->
        case time_type do
          :utc ->
            {:ok, time}

          :local ->
            times =
              time
              |> NaiveDateTime.to_erl()
              |> :calendar.local_time_to_universal_time_dst()
              |> Enum.map(fn dt -> NaiveDateTime.from_erl!(dt) end)

            case times do
              [] ->
                message = "Due to switching to DST, no valid timestamp for [#{time}] exists"
                Logger.warn(fn -> message end)
                {:error, message}

              [actual_time] ->
                {:ok, actual_time}

              [actual_time_dst, actual_time] ->
                Logger.warn(
                  "Due to switching from DST, two timestamps for [#{time}] exist; DST timestamp [#{
                    actual_time_dst
                  }] is ignored"
                )

                {:ok, actual_time}
            end
        end

      error ->
        error
    end
  end

  @doc """
  Parses the supplied arguments as `--key` `value` options, based on the expected arguments list.

  For example: `["--some-key", "some-value"]` will be parsed to `[:some_key, "some-value"]` if `:some_key` is expected.
  """

  def parse_as_options(expected_args, actual_args) do
    {parsed, _, _} = OptionParser.parse(actual_args, strict: expected_args)
    parsed
  end

  @doc """
  Parses the supplied arguments as positional options, based on the expected arguments list.

  For example: `["some-value"]` will be parsed to `[:some_key, "some-value"]` if `:some_key` is expected.
  """

  def parse_as_positional(expected_args, actual_args) do
    Enum.zip(
      Enum.map(expected_args, fn {arg, _} -> arg end),
      actual_args
    )
  end

  @doc """
  Parses the supplied arguments as `key=value` options, based on the expected arguments list.

  For example: `["some-key=some-value"]` will be parsed to `[:some_key, "some-value"]` if `:some_key` is expected.
  """

  def parse_as_kv(expected_args, actual_args) do
    parse_as_options(
      expected_args,
      Enum.flat_map(
        actual_args,
        fn arg -> String.split("--#{arg}", "=") end
      )
    )
  end

  @doc """
  Validates the supplied task name.
  """

  def parse_task(raw_task) do
    cond do
      raw_task && String.length(raw_task) > 0 -> {:ok, raw_task}
      true -> {:error, "No task specified"}
    end
  end

  @doc """
  Parses the supplied date string into a `Date` object.

  The supported formats are:
  - `today`       - gets the current day
  - `today+XXd`   - gets the current day and adds XX days (for example, today+3d)
  - `today-XXd`   - gets the current day and subtracts XX days (for example, today-3d)
  - `YYYY-MM-DD`  - sets the date explicitly (for example, 2015-12-21)
  """

  def parse_date(raw_date) do
    case Regex.run(~r/^(today)([-+])(\d+)([d])$|^today$/, raw_date) do
      ["today"] ->
        {:ok, Date.utc_today()}

      [_, "today", "+", days, "d"] ->
        {:ok, Date.add(Date.utc_today(), String.to_integer(days))}

      [_, "today", "-", days, "d"] ->
        {:ok, Date.add(Date.utc_today(), -String.to_integer(days))}

      _ ->
        case Regex.run(~r/^\d{4}-\d{2}-\d{2}/, raw_date) do
          [_ | _] ->
            Date.from_iso8601(raw_date)

          _ ->
            {:error, "Invalid date specified: [#{raw_date}]"}
        end
    end
  end

  @doc """
  Parses the supplied time string into a `Time` object.

  The supported formats are:
  - `now`       - gets current time
  - `now+XXm`   - gets the current time and adds XX minutes (for example, now+45m)
  - `now-XXm`   - gets the current time and subtracts XX minutes (for example, now-45m)
  - `now+XXh`   - gets the current time and adds XX hours (for example, now+1h)
  - `now-XXh`   - gets the current time and subtracts XX hours (for example, now-1h)
  - `HH:mm`     - sets the time explicitly (for example, 23:45)
  - `HH:mm:ss`  - sets the time explicitly (with seconds; for example, 23:45:59)
  """

  def parse_time(raw_time) do
    case Regex.run(~r/^(now)([-+])(\d+)([mh])$|^now$/, raw_time) do
      ["now"] ->
        {:ok, :utc, Time.utc_now()}

      [_, "now", "+", minutes, "m"] ->
        {:ok, :utc, Time.add(Time.utc_now(), String.to_integer(minutes) * 60, :second)}

      [_, "now", "-", minutes, "m"] ->
        {:ok, :utc, Time.add(Time.utc_now(), -String.to_integer(minutes) * 60, :second)}

      [_, "now", "+", hours, "h"] ->
        {:ok, :utc, Time.add(Time.utc_now(), String.to_integer(hours) * 3600, :second)}

      [_, "now", "-", hours, "h"] ->
        {:ok, :utc, Time.add(Time.utc_now(), -String.to_integer(hours) * 3600, :second)}

      _ ->
        parse_result =
          case Regex.run(~r/^\d{2}:\d{2}(:\d{2})?/, raw_time) do
            [time, _] ->
              Time.from_iso8601(time)

            [time] ->
              Time.from_iso8601("#{time}:00")

            _ ->
              {:error, "Invalid time specified: [#{raw_time}]"}
          end

        with {:ok, time} <- parse_result do
          {:ok, :local, time}
        end
    end
  end

  @doc """
  Parses the supplied duration string into minutes.

  The supported formats are:
  - `XXm` - XX minutes (for example, 95m == 95 minuets)
  - `XXh` - XX hours (for example, 11h == 660 minutes)
  """

  def parse_duration(raw_duration) do
    case Regex.run(~r/^(\d+)([mh])$/, raw_duration) do
      [_, minutes, "m"] ->
        {:ok, String.to_integer(minutes)}

      [_, hours, "h"] ->
        {:ok, String.to_integer(hours) * 60}

      _ ->
        {:error, "Invalid duration specified: [#{raw_duration}]"}
    end
  end
end
