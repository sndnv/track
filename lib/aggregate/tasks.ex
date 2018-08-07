defmodule Aggregate.Tasks do
  @moduledoc false

  def list_to_table(stream, query) do
    rows =
      stream
      |> with_local_time_zone()
      |> as_list()
      |> sorted(query)
      |> to_table_rows()

    case rows do
      [_ | _] ->
        table_header = ["ID", "Task", "Start", "Duration"]
        today = Date.utc_today()

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

        table =
          TableRex.Table.new(rows, table_header)
          |> TableRex.Table.put_column_meta(
            2,
            color: fn text, value ->
              cond do
                String.starts_with?(value, current_day) ->
                  [:green, text]

                Enum.any?(current_week_days, &String.starts_with?(value, &1)) ->
                  [:yellow, text]

                String.starts_with?(value, current_month) ->
                  [:red, text]

                true ->
                  text
              end
            end
          )
          |> TableRex.Table.put_column_meta(3, align: :right)
          |> TableRex.Table.render!()

        {:ok, table}

      [] ->
        {:error, "No data"}
    end
  end

  def with_local_time_zone(stream) do
    stream
    |> Stream.map(fn entry ->
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

  def sorted(list, query) do
    list
    |> Enum.sort_by(fn entry ->
      case query.sort_by do
        "task" -> entry.task
        "start" -> NaiveDateTime.to_string(entry.start)
        "duration" -> entry.duration
      end
    end)
    |> Enum.reverse()
  end

  def to_table_rows(list) do
    list
    |> Enum.map(fn entry ->
      [
        entry.id,
        entry.task,
        naive_date_time_to_string(entry.start),
        "#{entry.duration} m"
      ]
    end)
  end

  def naive_date_time_to_string(dt) do
    date = NaiveDateTime.to_date(dt)
    hours = dt.hour |> Integer.to_string() |> String.pad_leading(2, "0")
    minutes = dt.minute |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{date} #{hours}:#{minutes}"
  end
end
