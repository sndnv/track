defmodule Aggregate.Tasks do
  @moduledoc false

  def with_total_duration(stream, query) do
    result =
      stream
      |> with_local_time_zone()
      |> as_list()
      |> Enum.group_by(fn entry -> entry.task end)
      |> Enum.map(fn {task, entries} ->
        {task, entries |> Enum.reduce(0, fn entry, acc -> acc + entry.duration end), entries}
      end)
      |> Enum.sort_by(fn {task, duration, _} ->
        case query.sort_by do
          "task" -> task
          "duration" -> duration
          "start" -> duration
        end
      end)

    case query.order do
      "desc" -> result |> Enum.reverse()
      _ -> result
    end
  end

  def as_sorted_list(stream, query) do
    result =
      stream
      |> with_local_time_zone()
      |> as_list()
      |> Enum.sort_by(fn entry ->
        case query.sort_by do
          "task" -> entry.task
          "start" -> NaiveDateTime.to_string(entry.start)
          "duration" -> entry.duration
        end
      end)

    case query.order do
      "desc" -> result |> Enum.reverse()
      _ -> result
    end
  end

  def with_local_time_zone(list) do
    list
    |> Enum.map(fn entry ->
      start_with_time_zone =
        entry.start
        |> NaiveDateTime.to_erl()
        |> :calendar.universal_time_to_local_time()
        |> NaiveDateTime.from_erl!()

      %{entry | start: start_with_time_zone}
    end)
  end

  def as_list(stream) do
    stream
    |> Enum.to_list()
  end
end
