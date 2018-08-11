defmodule Cli.Render do
  @moduledoc false

  def duration_aggregation_as_bar_chart(aggregation) do
    case aggregation do
      [_ | _] ->
        default_width = 80
        duration_label_size = 9
        separator = " | "
        ellipsis = "..."
        block = "▇"

        max_shell_width = 180
        shell_width = min(max_shell_width, get_shell_width(default_width))
        max_label_size = trunc(shell_width * 0.25)

        {largest_label_size, largest_value} =
          aggregation
          |> Enum.reduce({0, 0}, fn {current_task, current_duration, _},
                                    {max_task_size, max_duration} ->
            {
              max(max_task_size, String.length(current_task)),
              max(max_duration, current_duration)
            }
          end)

        largest_label_size = min(largest_label_size, max_label_size)

        chart_header = "#{String.pad_trailing("Task", largest_label_size)}#{separator}Duration\n"

        current_periods = get_current_periods()

        chart =
          aggregation
          |> Enum.map(fn {task, total_duration, entries} ->
            task_label =
              if String.length(task) > largest_label_size do
                truncated = String.slice(task, 0, largest_label_size - String.length(ellipsis))
                "#{truncated}#{ellipsis}"
              else
                String.pad_trailing(task, largest_label_size)
              end

            duration_label =
              "#{duration_to_formatted_string(total_duration)} "
              |> String.pad_leading(duration_label_size)

            separator_size = String.length(separator)
            labels_size = largest_label_size + String.length(duration_label)

            max_value_size = shell_width - labels_size - separator_size

            chart_blocks = trunc(max_value_size * total_duration / largest_value)

            value =
              entries
              |> Enum.map(fn entry ->
                start_string = naive_date_time_to_string(entry.start)
                period = naive_date_time_to_period(entry.start, start_string, current_periods)
                {%{entry | start: start_string}, period}
              end)
              |> Enum.sort_by(fn {entry, _} -> entry.start end)
              |> Enum.reverse()
              |> Enum.map(fn {entry, period} ->
                entry_blocks = trunc(chart_blocks * entry.duration / total_duration)

                case period do
                  :future -> coloured_entry_chart_segment(block, entry_blocks, :blue)
                  :current_day -> coloured_entry_chart_segment(block, entry_blocks, :green)
                  :current_week -> coloured_entry_chart_segment(block, entry_blocks, :yellow)
                  :current_month -> coloured_entry_chart_segment(block, entry_blocks, :red)
                  :past -> entry_chart_segment(block, entry_blocks)
                end
              end)

            "#{task_label}#{separator}#{duration_label}#{value}"
          end)
          |> Enum.join("\n")

        {:ok, "#{chart_header}#{chart}"}

      [] ->
        {:error, "No data"}
    end
  end

  def list_as_table(list) do
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
        case naive_date_time_to_period(entry.start, start_string, current_periods) do
          :future -> {:ok, :blue}
          :current_day -> {:ok, :green}
          :current_week -> {:ok, :yellow}
          :current_month -> {:ok, :red}
          :past -> :skip
        end

      start_string =
        case date_colour do
          {:ok, colour} -> IO.ANSI.format([colour, start_string], true)
          :skip -> start_string
        end

      [
        entry.id,
        entry.task,
        start_string,
        duration_to_formatted_string(entry.duration)
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

  def naive_date_time_to_string(dt) do
    date = NaiveDateTime.to_date(dt)
    hours = dt.hour |> Integer.to_string() |> String.pad_leading(2, "0")
    minutes = dt.minute |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{date} #{hours}:#{minutes}"
  end

  def duration_to_formatted_string(duration) do
    duration = abs(duration)
    hours = div(duration, 60)
    minutes = (duration - hours * 60) |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{hours}:#{minutes}"
  end

  def get_shell_width(default_width) do
    case System.cmd("tput", ["cols"]) do
      {width, 0} -> width |> String.trim() |> String.to_integer()
      _ -> default_width
    end
  end
end
