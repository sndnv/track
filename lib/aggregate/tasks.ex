defmodule Aggregate.Tasks do
  @moduledoc false

  @day_seconds 24 * 60 * 60

  def per_day(stream, query) do
    result =
      stream
      |> with_local_time_zone()
      |> Enum.flat_map(fn entry ->
        start_day = entry.start |> NaiveDateTime.to_date()
        start_day_string = start_day |> Date.to_string()

        entry_end =
          entry.start
          |> NaiveDateTime.add(entry.duration * 60, :second)

        end_day = entry_end |> NaiveDateTime.to_date()
        end_day_string = end_day |> Date.to_string()

        if start_day_string != end_day_string do
          {:ok, start_day_end} = "#{start_day_string}T23:59:59" |> NaiveDateTime.from_iso8601()
          start_day_end = start_day_end |> NaiveDateTime.add(1, :second)

          current_day_seconds = NaiveDateTime.diff(start_day_end, entry.start, :second)
          remaining_entry_seconds = entry.duration * 60 - current_day_seconds
          current_day_task = %{entry | duration: div(current_day_seconds, 60)}

          {result, _} =
            0..div(remaining_entry_seconds, @day_seconds)
            |> Enum.reduce(
              {[{current_day_task, start_day_string}], remaining_entry_seconds},
              fn day_number, {new_entries, remaining_seconds} ->
                new_entry_day = start_day |> Date.add(day_number + 1)
                new_entry_day_string = new_entry_day |> Date.to_string()

                {:ok, new_entry_start} =
                  "#{new_entry_day_string}T00:00:00" |> NaiveDateTime.from_iso8601()

                new_entry_duration =
                  if remaining_seconds >= @day_seconds do
                    @day_seconds
                  else
                    remaining_seconds
                  end

                new_entry = %{
                  entry
                  | start: new_entry_start,
                    duration: div(new_entry_duration, 60)
                }

                {
                  [{new_entry, new_entry_day_string} | new_entries],
                  remaining_seconds - new_entry_duration
                }
              end
            )

          result |> Enum.filter(fn {entry, _} -> entry.duration > 0 end)
        else
          [{entry, start_day_string}]
        end
      end)
      |> as_list()
      |> Enum.group_by(fn {_, start_day} -> start_day end)
      |> Enum.map(fn {start_day, entries} ->
        entries = entries |> Enum.map(fn {entry, _} -> entry end)
        {start_day, entries |> Enum.reduce(0, fn entry, acc -> acc + entry.duration end), entries}
      end)
      |> Enum.sort_by(fn {start_day, duration, _} ->
        case query.sort_by do
          "task" -> start_day
          "duration" -> duration
          "start" -> start_day
        end
      end)

    case query.order do
      "desc" -> result |> Enum.reverse()
      _ -> result
    end
  end

  def with_no_duration(stream) do
    stream
    |> Stream.filter(fn entry -> entry.duration <= 0 end)
    |> as_list()
  end

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
