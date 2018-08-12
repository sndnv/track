defmodule Cli.Parse do
  @moduledoc false

  require Logger

  @application_options [verbose: :boolean, config: :string]

  @spec extract_application_options([String.to()]) :: {[{atom, term}], [String.t()]}
  def extract_application_options(args) do
    {options, _, _} = OptionParser.parse(args, strict: @application_options)

    parsed_args = Enum.flat_map(options, fn {k, v} -> ["--#{Atom.to_string(k)}", v] end)
    remaining_args = Enum.reject(args, fn arg -> Enum.member?(parsed_args, arg) end)

    {options, remaining_args}
  end

  @expected_query_args [
    from: :string,
    to: :string,
    sort_by: :string,
    order: :string
  ]

  @spec args_to_query([String.t()]) :: Api.Query.t()
  def args_to_query(args) do
    parsed =
      case args do
        [head | _] ->
          parsed =
            cond do
              String.starts_with?(head, "--") -> parse_as_options(@expected_query_args, args)
              String.contains?(head, "=") -> parse_as_kv(@expected_query_args, args)
              true -> parse_as_positional(@expected_query_args, args)
            end

          Enum.map(parsed, fn {k, v} -> {k, String.downcase(v)} end)

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

  @spec args_to_task([String.t()]) :: Api.Task.t()
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

        parsed =
          Enum.map(
            parsed,
            fn {key, value} ->
              updated_value = if key != :task, do: String.downcase(value), else: value
              {key, updated_value}
            end
          )

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

  @spec duration_from_parsed_args([{atom, String.t()}], NaiveDateTime.t(), String.t()) ::
          {:ok, integer} | {:error, String.t()}
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
        day_minutes = 24 * 60

        with {:ok, end_time_type, end_time} <- parse_time(parsed_args[:end_time]),
             {:ok, end_utc} <- from_local_time_zone(start_date, end_time, end_time_type) do
          case NaiveDateTime.compare(
                 NaiveDateTime.truncate(end_utc, :second),
                 NaiveDateTime.truncate(start_utc, :second)
               ) do
            :lt ->
              {:ok, div(NaiveDateTime.diff(end_utc, start_utc, :second), 60) + day_minutes}

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

  @spec from_local_time_zone(String.t(), String.t(), atom) ::
          {:ok, NaiveDateTime.t()} | {:error, String.t()}
  def from_local_time_zone(date, time, time_type) do
    case NaiveDateTime.from_iso8601("#{date}T#{time}") do
      {:ok, time} ->
        case time_type do
          :utc ->
            {:ok, time}

          :local ->
            dts =
              time
              |> NaiveDateTime.to_erl()
              |> :calendar.local_time_to_universal_time_dst()
              |> Enum.map(fn dt -> NaiveDateTime.from_erl!(dt) end)

            case dts do
              [] ->
                {:error, "Period skipped due to switching to DST"}

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

  @spec parse_as_options([{atom, atom}], [String.t()]) :: [{atom, String.t()}]
  def parse_as_options(expected_args, actual_args) do
    {parsed, _, _} = OptionParser.parse(actual_args, strict: expected_args)
    parsed
  end

  @spec parse_as_positional([{atom, atom}], [String.t()]) :: [{atom, String.t()}]
  def parse_as_positional(expected_args, acual_args) do
    Enum.zip(
      Enum.map(expected_args, fn {arg, _} -> arg end),
      acual_args
    )
  end

  @spec parse_as_kv([{atom, atom}], [String.t()]) :: [{atom, String.t()}]
  def parse_as_kv(expected_args, actual_args) do
    parse_as_options(
      expected_args,
      Enum.flat_map(
        actual_args,
        fn arg -> String.split("--#{arg}", "=") end
      )
    )
  end

  @spec parse_task(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def parse_task(raw_task) do
    cond do
      String.length(raw_task) > 0 -> {:ok, raw_task}
      true -> {:error, "No task specified"}
    end
  end

  @spec parse_date(String.t()) :: {:ok, Date.t()} | {:error, String.t()}
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

  @spec parse_time(String.t()) ::
          {:ok, :utc, Time.t()} | {:ok, :local, Time.t()} | {:error, String.t()}
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

  @spec parse_duration(String.t()) :: {:ok, integer} | {:error, String.t()}
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
