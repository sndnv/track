defmodule Cli.Parse do
  @moduledoc false

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
    sort_by: :string
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
         {:ok, from, 0} <- DateTime.from_iso8601("#{from_date}T00:00:00Z"),
         {:ok, to, 0} <- DateTime.from_iso8601("#{to_date}T23:59:59Z"),
         sort_by <- Keyword.get(parsed, :sort_by, "start") do
      {
        :ok,
        %Api.Query{
          from: from,
          to: to,
          sort_by: sort_by
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
             {:ok, start_time} <- parse_time(Keyword.get(parsed, :start_time, "now")),
             {:ok, duration} <- duration_from_parsed_args(parsed, start_time),
             {:ok, start, 0} <- DateTime.from_iso8601("#{start_date}T#{start_time}Z") do
          {
            :ok,
            %Api.Task{
              id: UUID.uuid4(),
              task: task,
              start: start,
              duration: duration
            }
          }
        end

      [] ->
        {:error, "No arguments specified"}
    end
  end

  @spec duration_from_parsed_args([{atom, String.t()}], Time.t()) ::
          {:ok, integer} | {:error, String.t()}
  def duration_from_parsed_args(parsed_args, start_time) do
    cond do
      parsed_args[:duration] ->
        parse_duration(parsed_args[:duration])

      parsed_args[:end_time] ->
        day_minutes = 24 * 60

        case parse_time(parsed_args[:end_time]) do
          {:ok, end_time} ->
            case Time.compare(
                   Time.truncate(end_time, :second),
                   Time.truncate(start_time, :second)
                 ) do
              :lt ->
                {:ok, trunc(Time.diff(end_time, start_time, :second) / 60) + day_minutes}

              :gt ->
                {:ok, trunc(Time.diff(end_time, start_time, :second) / 60)}

              :eq ->
                {:error, "The specified start and end times are the same"}
            end

          {:error, message} ->
            {:error, "Failed to parse end time: [#{message}]"}
        end

      true ->
        {:ok, 0}
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

  @spec parse_time(String.t()) :: {:ok, Time.t()} | {:error, String.t()}
  def parse_time(raw_time) do
    case Regex.run(~r/^(now)([-+])(\d+)([mh])$|^now$/, raw_time) do
      ["now"] ->
        {:ok, Time.utc_now()}

      [_, "now", "+", minutes, "m"] ->
        {:ok, Time.add(Time.utc_now(), String.to_integer(minutes) * 60, :second)}

      [_, "now", "-", minutes, "m"] ->
        {:ok, Time.add(Time.utc_now(), -String.to_integer(minutes) * 60, :second)}

      [_, "now", "+", hours, "h"] ->
        {:ok, Time.add(Time.utc_now(), String.to_integer(hours) * 3600, :second)}

      [_, "now", "-", hours, "h"] ->
        {:ok, Time.add(Time.utc_now(), -String.to_integer(hours) * 3600, :second)}

      _ ->
        case Regex.run(~r/^\d{2}:\d{2}(:\d{2})?/, raw_time) do
          [time, _] ->
            Time.from_iso8601(time)

          [time] ->
            Time.from_iso8601("#{time}:00")

          _ ->
            {:error, "Invalid time specified: [#{raw_time}]"}
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
