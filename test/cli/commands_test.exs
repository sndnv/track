defmodule Cli.CommandsTest do
  @moduledoc false

  use ExUnit.Case

  setup do
    start_supervised!({
      Api.Service,
      name: Api, api_options: %{store: Persistence.Memory, store_options: %{}}
    })

    :ok
  end

  test "adds tasks" do
    args = [
      "--task",
      "test-task",
      "--start-date",
      "2018-12-21",
      "--start-time",
      "21:35",
      "--end-time",
      "23:00"
    ]

    assert Cli.Commands.add_task(args) == :ok
  end

  test "removes tasks" do
    valid_id = "56f3db20-88c9-44ba-a0f1-da78dc990b84"
    args = [valid_id]
    assert Cli.Commands.remove_task(args) == :ok

    invalid_id = "invalid-id"
    args = [invalid_id]
    assert Cli.Commands.remove_task(args) == {:error, "[#{invalid_id}] is not a valid task ID"}

    args = []
    assert Cli.Commands.remove_task(args) == {:error, "Task ID is required"}
  end

  test "updates tasks" do
    valid_id = "56f3db20-88c9-44ba-a0f1-da78dc990b84"
    args = [valid_id, "--task", "test-task"]
    assert Cli.Commands.update_task(args) == {:error, "Task with ID [#{valid_id}] was not found"}

    args = [valid_id]
    assert Cli.Commands.update_task(args) == {:error, "No or unparsable arguments specified"}

    invalid_id = "invalid-id"
    args = [invalid_id]
    assert Cli.Commands.update_task(args) == {:error, "[#{invalid_id}] is not a valid task ID"}

    args = []
    assert Cli.Commands.update_task(args) == {:error, "Task ID is required"}
  end

  test "starts tasks" do
    args = ["test-task"]
    assert Cli.Commands.start_task(args) == :ok

    args = []
    assert Cli.Commands.start_task(args) == {:error, "Task is required"}

    assert Cli.Commands.stop_task() == :ok
  end

  test "stops tasks" do
    args = ["test-task"]
    assert Cli.Commands.start_task(args) == :ok

    assert Cli.Commands.stop_task() == :ok

    assert Cli.Commands.stop_task() == {:error, "No active tasks found"}
  end

  test "lists tasks" do
    args = []
    assert Cli.Commands.list(args) == {:error, "No data"}
  end

  test "generates reports" do
    args = ["duration"]
    assert Cli.Commands.report(args) == {:error, "No data"}

    args = ["day"]
    assert Cli.Commands.report(args) == {:error, "No data"}

    args = ["week"]
    assert Cli.Commands.report(args) == {:error, "No data"}

    args = ["month"]
    assert Cli.Commands.report(args) == {:error, "No data"}

    args = ["task", "test-task"]
    assert Cli.Commands.report(args) == {:error, "No data"}

    args = ["overlap"]
    assert Cli.Commands.report(args) == {:error, "No data"}

    args = ["invalid"]
    assert Cli.Commands.report(args) == {:error, "[invalid] report not supported"}

    args = []
    assert Cli.Commands.report(args) == {:error, "No report specified"}
  end

  test "processes service commands" do
    args = ["store", "clear"]
    assert Cli.Commands.service(args) == :ok

    args = ["store"]
    assert Cli.Commands.service(args) == {:error, "No service parameters specified"}

    args = []
    assert Cli.Commands.service(args) == {:error, "Service name is required"}
  end

  test "generates list/report legend" do
    {:output, result} = Cli.Commands.legend()
    assert String.split(result, "\n") |> Enum.count() > 0
  end

  test "generates the help message" do
    args = ["stop"]
    {:output, result} = Cli.Commands.help(args)
    assert String.split(result, "\n") |> Enum.count() > 0

    args = []
    {:output, result} = Cli.Commands.help(args)
    assert String.split(result, "\n") |> Enum.count() > 0

    args = ["invalid"]
    {:error, error} = Cli.Commands.help(args)
    assert error == "No help found for command [invalid]"
  end
end
