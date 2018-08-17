defmodule Api.Fixtures do
  @moduledoc false

  use ExUnit.CaseTemplate

  def mock_tasks() do
    {:ok, start_time} = NaiveDateTime.from_iso8601("1999-09-15T01:02:03")

    task_0 = {
      :ok,
      %Api.Task{
        id: UUID.uuid4(),
        task: "test-task-active",
        start: start_time,
        duration: 0
      }
    }

    task_1 = {
      :ok,
      %Api.Task{
        id: UUID.uuid4(),
        task: "test-task1",
        start: NaiveDateTime.add(start_time, 10, :second),
        duration: 60
      }
    }

    task_2 = {
      :ok,
      %Api.Task{
        id: UUID.uuid4(),
        task: "test-task2",
        start: NaiveDateTime.add(start_time, 90, :second),
        duration: 10
      }
    }

    task_3 = {
      :ok,
      %Api.Task{
        id: UUID.uuid4(),
        task: "test-task3",
        start: NaiveDateTime.add(start_time, 20, :second),
        duration: 20
      }
    }

    failure_0 = {:error, "Test error #1"}

    failure_1 = {:error, "Test error #2"}

    failure_2 = {:error, "Test error #2"}

    failure_3 = {:error, "Test error #3"}

    [task_0, task_1, failure_0, task_2, task_3, failure_1, failure_2, failure_3]
  end

  def mock_tasks_stream(tasks) do
    Stream.map(tasks, fn e -> e end)
  end
end
