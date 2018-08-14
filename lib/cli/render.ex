defmodule Cli.Render do
  @moduledoc false

  @bar_chart_block "▇"
  @bar_chart_empty_block "-"
  @bar_chart_ellipsis "..."
  @day_minutes 24 * 60

  def daily_aggregation_as_bar_chart(aggregation, query) do
    case aggregation do
      [_ | _] ->
        current_periods = get_current_periods()

        header = [label: "Start Date", value_label: "Duration"]

        footer = [label: "Daily task distribution between [#{query.from}] and [#{query.to}]"]

        minutes =
          1..@day_minutes
          |> Enum.map(fn minute ->
            {minute, :empty}
          end)
          |> Enum.into(%{})

        rows =
          aggregation
          |> Enum.map(fn {start_day, total_duration, entries} ->
            formatted_total_duration =
              "#{duration_to_formatted_string(total_duration, Enum.at(entries, 0).start)} "

            day_string = "#{start_day}T00:00:00"
            {:ok, day} = NaiveDateTime.from_iso8601(day_string)

            colour =
              naive_date_time_to_period(day, day_string, current_periods)
              |> period_to_colour()

            entries =
              entries
              |> Enum.flat_map(fn entry ->
                offset = div(NaiveDateTime.diff(entry.start, day, :second), 60)

                offset..(offset + entry.duration - 1)
                |> Enum.map(fn minute -> {minute + 1, colour} end)
              end)
              |> Enum.into(%{})

            entries =
              Map.merge(minutes, entries)
              |> Enum.sort_by(fn {minute, _} -> minute end)
              |> Enum.reverse()
              |> Enum.reduce(%{}, fn {_, colour}, acc ->
                block_id = max(Map.size(acc) - 1, 0)

                block_op =
                  case Map.get(acc, block_id, {0, colour}) do
                    {block_size, ^colour} -> {:update, {block_size + 1, colour}}
                    _ -> {:add, {1, colour}}
                  end

                case block_op do
                  {:add, block_data} -> Map.put(acc, block_id + 1, block_data)
                  {:update, block_data} -> Map.put(acc, block_id, block_data)
                end
              end)
              |> Enum.map(fn {_, entry} -> entry end)

            {start_day, @day_minutes, formatted_total_duration, entries}
          end)

        {:ok, bar_chart(header, rows, footer)}

      [] ->
        {:error, "No data"}
    end
  end

  def duration_aggregation_as_bar_chart(aggregation, query) do
    case aggregation do
      [_ | _] ->
        current_periods = get_current_periods()

        header = [label: "Task", value_label: "Duration"]

        footer = [label: "Total duration of tasks between [#{query.from}] and [#{query.to}]"]

        rows =
          aggregation
          |> Enum.map(fn {task, total_duration, entries} ->
            formatted_total_duration =
              "#{duration_to_formatted_string(total_duration, Enum.at(entries, 0).start)} "

            entries =
              entries
              |> Enum.map(fn entry ->
                start_string = naive_date_time_to_string(entry.start)

                colour =
                  naive_date_time_to_period(entry.start, start_string, current_periods)
                  |> period_to_colour()

                {%{entry | start: start_string}, colour}
              end)
              |> Enum.sort_by(fn {entry, _} -> entry.start end)
              |> Enum.map(fn {entry, colour} ->
                {entry.duration, colour}
              end)

            {task, total_duration, formatted_total_duration, entries}
          end)

        {:ok, bar_chart(header, rows, footer)}

      [] ->
        {:error, "No data"}
    end
  end

  def table(list) do
    rows = list |> to_table_rows()

    case rows do
      [_ | _] ->
        table_header = ["ID", "Task", "Start", "Duration"]

        table =
          TableRex.Table.new(rows, table_header)
          |> TableRex.Table.put_column_meta(3, align: :right)
          |> TableRex.Table.render!()

        {:ok, table}

      [] ->
        {:error, "No data"}
    end
  end

  def period_colour_legend() do
    [
      current_day: "Today's tasks",
      current_week: "This week's tasks",
      current_month: "This month's tasks",
      future: "Future tasks",
      past: "Older tasks"
    ]
    |> Enum.map(fn {period, description} ->
      block =
        case period_to_colour(period) do
          :default -> @bar_chart_block
          colour -> IO.ANSI.format([colour, @bar_chart_block], true)
        end

      " #{block} -> #{description}"
    end)
  end

  def bar_chart(header, rows, footer) do
    default_width = 80
    separator = " | "

    {largest_label_size, largest_value_label_size, largest_value} =
      rows
      |> Enum.reduce({0, 0, 0}, fn {current_label, current_value, current_formatted_value, _},
                                   {max_label_size, max_value_label_size, max_value} ->
        {
          max(max_label_size, String.length(current_label)),
          max(max_value_label_size, String.length(current_formatted_value)),
          max(max_value, current_value)
        }
      end)

    max_shell_width = 180
    shell_width = min(max_shell_width, get_shell_width(default_width))
    max_label_size = trunc(shell_width * 0.25)

    largest_label_size = min(largest_label_size, max_label_size)

    chart_header =
      "#{String.pad_trailing(header[:label], largest_label_size)}#{separator}#{
        header[:value_label]
      }\n"

    chart_separator =
      "#{String.pad_trailing("", largest_label_size, "-")} + #{
        String.pad_trailing("", String.length(header[:value_label]), "-")
      }\n"

    chart_header = "#{chart_header}#{chart_separator}"

    chart_footer = "\n#{chart_separator}#{footer[:label]}"

    chart =
      rows
      |> Enum.map(fn {label, total_value, formatted_total_value, entries} ->
        label =
          if String.length(label) > largest_label_size do
            truncated =
              String.slice(label, 0, largest_label_size - String.length(@bar_chart_ellipsis))

            "#{truncated}#{@bar_chart_ellipsis}"
          else
            String.pad_trailing(label, largest_label_size)
          end

        value_label =
          formatted_total_value
          |> String.pad_leading(largest_value_label_size)

        separator_size = String.length(separator)
        labels_size = largest_label_size + String.length(value_label)

        max_value_size = shell_width - labels_size - separator_size

        chart_blocks = trunc(max_value_size * total_value / largest_value)

        {_, entries} =
          entries
          |> Enum.reduce({0, []}, fn {size, colour}, {remainder, entries} ->
            current_remainder = rem(chart_blocks * size, total_value)

            cond do
              current_remainder == 0 ->
                {
                  remainder,
                  [{div(chart_blocks * size, total_value), colour} | entries]
                }

              remainder == 0 ->
                {
                  current_remainder,
                  [{div(chart_blocks * size, total_value), colour} | entries]
                }

              true ->
                updated_remainder = rem(chart_blocks * size + remainder, total_value)
                entry_blocks = div(chart_blocks * size + remainder, total_value)

                {
                  updated_remainder,
                  [{entry_blocks, colour} | entries]
                }
            end
          end)

        value =
          entries
          |> Enum.map(fn {entry_blocks, colour} ->
            if entry_blocks > 0 do
              case colour do
                :default -> entry_chart_segment(@bar_chart_block, entry_blocks)
                :empty -> entry_chart_segment(@bar_chart_empty_block, entry_blocks)
                colour -> coloured_entry_chart_segment(@bar_chart_block, entry_blocks, colour)
              end
            else
              ""
            end
          end)

        "#{label}#{separator}#{value_label}#{value}"
      end)
      |> Enum.join("\n")

    "#{chart_header}#{chart}#{chart_footer}"
  end

  def coloured_entry_chart_segment(block, num_blocks, colour) do
    IO.ANSI.format(
      [colour, entry_chart_segment(block, num_blocks)],
      true
    )
  end

  def entry_chart_segment(block, num_blocks) do
    List.duplicate(block, num_blocks)
  end

  def to_table_rows(list) do
    current_periods = get_current_periods()

    list
    |> Enum.map(fn entry ->
      start_string = naive_date_time_to_string(entry.start)

      date_colour =
        naive_date_time_to_period(entry.start, start_string, current_periods)
        |> period_to_colour()

      start_string =
        case date_colour do
          :default -> start_string
          colour -> IO.ANSI.format([colour, start_string], true)
        end

      [
        entry.id,
        entry.task,
        start_string,
        duration_to_formatted_string(entry.duration, entry.start)
      ]
    end)
  end

  def get_current_periods() do
    now = NaiveDateTime.utc_now()

    today = NaiveDateTime.to_date(now)

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

    {now, current_day, current_week_days, current_month}
  end

  def naive_date_time_to_period(
        dt,
        dt_string,
        {now, current_day, current_week_days, current_month}
      ) do
    cond do
      String.starts_with?(dt_string, current_day) ->
        :current_day

      NaiveDateTime.compare(dt, now) == :gt ->
        :future

      Enum.any?(current_week_days, &String.starts_with?(dt_string, &1)) ->
        :current_week

      String.starts_with?(dt_string, current_month) ->
        :current_month

      true ->
        :past
    end
  end

  def period_to_colour(period) do
    case period do
      :future -> :blue
      :current_day -> :green
      :current_week -> :yellow
      :current_month -> :red
      :past -> :default
    end
  end

  def naive_date_time_to_string(dt) do
    date = NaiveDateTime.to_date(dt)
    hours = dt.hour |> Integer.to_string() |> String.pad_leading(2, "0")
    minutes = dt.minute |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{date} #{hours}:#{minutes}"
  end

  def duration_to_formatted_string(duration, start) do
    duration = abs(duration)

    if duration > 0 do
      hours = div(duration, 60)
      minutes = (duration - hours * 60) |> Integer.to_string() |> String.pad_leading(2, "0")
      "#{hours}:#{minutes}"
    else
      local_now = :calendar.local_time() |> NaiveDateTime.from_erl!()

      expected_duration =
        NaiveDateTime.diff(local_now, start, :second)
        |> div(60)

      if expected_duration > 0 do
        "(A) #{duration_to_formatted_string(expected_duration, start)}"
      else
        "(A) 0:00"
      end
    end
  end

  def get_shell_width(default_width) do
    case System.cmd("tput", ["cols"]) do
      {width, 0} -> width |> String.trim() |> String.to_integer()
      _ -> default_width
    end
  end
end
