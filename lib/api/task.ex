defmodule Api.Task do
  @moduledoc false

  @enforce_keys [:task, :start_date, :start_time, :duration]
  defstruct [:task, :start_date, :start_time, :duration]

  # doc - delta in days
  def with_start_date(task, delta) do
    case delta do
      {:plus, :days, days} -> %{task | start_date: Date.add(task.start_date, days)}
      {:minus, :days, days} -> %{task | start_date: Date.add(task.start_date, -days)}
      {:set, start_date} -> %{task | start_date: start_date}
    end
  end

  # doc - delta in minutes or hours
  def with_start_time(task, delta) do
    case delta do
      {:plus, :minutes, minutes} -> %{task | start_time: Time.add(task.start_time, :minute, minutes)}
      {:minus, :minutes, minutes} -> %{task | start_time: Time.add(task.start_time, :minute, -minutes)}
      {:plus, :hours, hours} -> %{task | start_time: Time.add(task.start_time, :hour, hours)}
      {:minus, :hours, hours} -> %{task | start_time: Time.add(task.start_time, :hour, -hours)}
      {:set, start_time} -> %{task | start_time: start_time}
    end
  end

  # doc - delta in minutes
  def with_duration(task, delta) do
    case delta do
      {:plus, :minutes, minutes} -> %{task | duration: task.duration + minutes}
      {:minus, :minutes, minutes} -> %{task | duration: task.duration - minutes}
      {:set, duration} -> %{task | duration: duration}
    end
  end
end
