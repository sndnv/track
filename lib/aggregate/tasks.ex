defmodule Aggregate.Tasks do
  @moduledoc false

  @day_seconds 24 * 60 * 60

  def per_period_for_a_task(stream, query, task_regex, group_period) do
    stream
    |> Stream.filter(fn entry -> Regex.match?(task_regex, entry.task) end)
    |> per_period(query, group_period)
  end

  def per_period(stream, query, group_period) do
    result =
      stream
      |> without_active_tasks()
      |> with_local_time_zone()
      |> Enum.flat_map(fn entry -> split_task_per_day(entry) end)
      |> as_list()
      |> Enum.map(fn {entry, start_day} ->
        {entry, task_start_day_to_period(start_day, group_period)}
      end)
      |> Enum.group_by(fn {_, period} -> period end)
      |> Enum.map(fn {period, entries} ->
        entries = entries |> Enum.map(fn {entry, _} -> entry end)
        {period, entries |> Enum.reduce(0, fn entry, acc -> acc + entry.duration end), entries}
      end)
      |> Enum.sort_by(fn {period, duration, _} ->
        case query.sort_by do
          "task" -> period
          "duration" -> duration
          "start" -> period
        end
      end)

    case query.order do
      "desc" -> result |> Enum.reverse()
      _ -> result
    end
  end

  def with_overlapping_periods(stream) do
    tasks_list =
      stream
      |> without_active_tasks()
      |> with_local_time_zone()
      |> as_list()

    tasks_map =
      tasks_list
      |> Enum.map(fn entry -> {entry.id, entry} end)
      |> Map.new()

    tasks_list
    |> Enum.flat_map(fn entry -> split_task_per_day(entry) end)
    |> Enum.map(fn {entry, start_day} ->
      {:ok, start_day} = NaiveDateTime.from_iso8601("#{start_day}T00:00:00")
      offset = div(NaiveDateTime.diff(entry.start, start_day, :second), 60)

      minutes =
        offset..(offset + entry.duration - 1)
        |> Enum.map(fn minute -> {minute + 1, entry.id} end)

      {start_day, minutes}
    end)
    |> Enum.group_by(fn {start_day, _} ->
      start_day
    end)
    |> Enum.map(fn {start_day, entry_minutes} ->
      overlapping_entries =
        entry_minutes
        |> Enum.reduce(
          %{},
          fn {_, current_minutes}, acc ->
            Map.merge(
              current_minutes |> Map.new(),
              acc,
              fn _k, v1, v2 -> if is_list(v2), do: [v1 | v2], else: [v1 | [v2]] end
            )
          end
        )
        |> Enum.flat_map(fn {_, entry_ids} ->
          if is_list(entry_ids) && length(entry_ids) > 1, do: entry_ids, else: []
        end)
        |> Enum.uniq()

      {
        start_day,
        overlapping_entries
        |> Enum.map(fn entry_id -> Map.get(tasks_map, entry_id) end)
        |> Enum.sort_by(fn entry -> entry.start end)
      }
    end)
    |> Enum.filter(fn {_, entry_ids} -> length(entry_ids) > 0 end)
  end

  def with_no_duration(stream) do
    stream
    |> Stream.filter(fn entry -> entry.duration <= 0 end)
    |> as_list()
  end

  def with_total_duration(stream, query) do
    result =
      stream
      |> without_active_tasks()
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

  def task_start_day_to_period(start_day, group_period) do
    case group_period do
      :day ->
        start_day |> Date.to_string()

      :week ->
        week_monday =
          Date.add(
            start_day,
            -(Calendar.ISO.day_of_week(start_day.year, start_day.month, start_day.day) - 1)
          )

        week_monday |> Date.to_string()

      :month ->
        "#{start_day.year}-#{start_day.month |> Integer.to_string() |> String.pad_leading(2, "0")}"
    end
  end

  def split_task_per_day(entry) do
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
          {[{current_day_task, start_day}], remaining_entry_seconds},
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
              [{new_entry, new_entry_day} | new_entries],
              remaining_seconds - new_entry_duration
            }
          end
        )

      result |> Enum.filter(fn {entry, _} -> entry.duration > 0 end)
    else
      [{entry, start_day}]
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

  def without_active_tasks(stream) do
    stream
    |> Stream.filter(fn entry -> entry.duration > 0 end)
  end

  def as_list(stream) do
    stream
    |> Enum.to_list()
  end
end
