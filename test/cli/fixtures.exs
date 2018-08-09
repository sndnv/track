defmodule Cli.Fixtures do
  @moduledoc false

  use ExUnit.CaseTemplate

  def mock_tasks() do
    {:ok, start_time} = NaiveDateTime.from_iso8601("2018-12-21T01:02:03Z")

    expected_task_1 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task1",
      start: NaiveDateTime.add(start_time, 10, :second),
      duration: 60
    }

    expected_task_2 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task2",
      start: NaiveDateTime.add(start_time, 90, :second),
      duration: 10
    }

    expected_task_3 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task3",
      start: NaiveDateTime.add(start_time, 20, :second),
      duration: 20
    }

    [expected_task_1, expected_task_2, expected_task_3]
  end

  def mock_tasks_stream(tasks) do
    Stream.map(tasks, fn e -> e end)
  end
end
