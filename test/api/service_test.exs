defmodule Api.ServiceTest do
  @moduledoc false

  use ExUnit.Case

  setup do
    start_supervised!({
      Api.Service,
      name: Api, api_options: %{store: Persistence.Memory, store_options: %{}}
    })

    :ok
  end

  test "flattens a stream of tasks" do
    tasks = Api.Fixtures.mock_tasks()
    stream = Api.Fixtures.mock_tasks_stream(tasks)

    actual_tasks = Api.Service.flatten(stream) |> Aggregate.Tasks.as_list()

    expected_tasks =
      tasks
      |> Enum.flat_map(fn e ->
        case e do
          {:ok, task} -> [task]
          _ -> []
        end
      end)

    assert actual_tasks == expected_tasks
  end

  test "applies query filters to a stream of tasks" do
    tasks = Api.Fixtures.mock_tasks()
    stream = Api.Fixtures.mock_tasks_stream(tasks)

    {:ok, task} = Enum.at(tasks, 0)
    tasks_start = task.start

    query = %Api.Query{
      from: task.start,
      to: task.start |> NaiveDateTime.add(30, :second),
      sort_by: "task",
      order: "asc"
    }

    actual_tasks =
      Api.Service.flatten(stream)
      |> Api.Service.with_query_filter(query)
      |> Aggregate.Tasks.as_list()

    expected_tasks =
      tasks
      |> Enum.flat_map(fn e ->
        case e do
          {:ok, task} ->
            diff = NaiveDateTime.diff(task.start, tasks_start, :second) |> abs()
            if diff <= 30, do: [task], else: []

          _ ->
            []
        end
      end)

    assert actual_tasks == expected_tasks
  end

  test "adds tasks" do
    {:ok, start_time} = NaiveDateTime.from_iso8601("1999-09-15T01:02:03")

    expected_task_1 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task-1",
      start: start_time,
      duration: 1
    }

    query = %Api.Query{
      from: start_time,
      to: start_time,
      sort_by: "task",
      order: "asc"
    }

    assert Api.Service.add_task(expected_task_1) == :ok

    {:ok, actual_tasks} = Api.Service.list_tasks(query)
    assert actual_tasks |> Enum.count() == 1
  end

  test "removes tasks" do
    {:ok, start_time} = NaiveDateTime.from_iso8601("1999-09-15T01:02:03")

    expected_task_1 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task-1",
      start: start_time,
      duration: 1
    }

    query = %Api.Query{
      from: start_time,
      to: start_time,
      sort_by: "task",
      order: "asc"
    }

    assert Api.Service.add_task(expected_task_1) == :ok

    {:ok, actual_tasks} = Api.Service.list_tasks(query)
    assert actual_tasks |> Enum.count() == 1

    assert Api.Service.remove_task(expected_task_1.id) == :ok

    {:ok, actual_tasks} = Api.Service.list_tasks(query)
    assert actual_tasks |> Enum.count() == 0
  end

  test "updates tasks" do
    {:ok, start_time} = NaiveDateTime.from_iso8601("1999-09-15T01:02:03")

    expected_task_1 = %Api.Task{
      id: UUID.uuid4(),
      task: "test-task-1",
      start: start_time,
      duration: 1
    }

    query = %Api.Query{
      from: start_time,
      to: start_time,
      sort_by: "task",
      order: "asc"
    }

    assert Api.Service.add_task(expected_task_1) == :ok

    {:ok, actual_tasks} = Api.Service.list_tasks(query)
    assert Enum.at(actual_tasks, 0).task == expected_task_1.task

    assert Api.Service.update_task(expected_task_1.id, %Api.TaskUpdate{task: "updated-task-name"}) ==
             :ok

    {:ok, actual_tasks} = Api.Service.list_tasks(query)
    assert Enum.at(actual_tasks, 0).task == "updated-task-name"

    assert Api.Service.update_task("invalid-id", %Api.TaskUpdate{task: "name"}) ==
             {:error, "Task with ID [invalid-id] was not found"}
  end

  test "starts tasks" do
    start_time = NaiveDateTime.utc_now()

    assert Api.Service.start_task("new-task") == :ok

    query = %Api.Query{
      from: start_time,
      to: start_time,
      sort_by: "task",
      order: "asc"
    }

    {:ok, actual_tasks} = Api.Service.list_tasks(query)
    assert actual_tasks |> Enum.count() == 1

    assert Api.Service.start_task("new-task") |> Tuple.to_list() |> Enum.at(0) == :error
  end

  test "stops tasks" do
    start_time = NaiveDateTime.utc_now()

    assert Api.Service.stop_task() == {:error, "No active tasks found"}

    assert Api.Service.start_task("new-task") == :ok

    query = %Api.Query{
      from: start_time |> NaiveDateTime.add(-30 * 60, :second),
      to: start_time |> NaiveDateTime.add(30 * 60, :second),
      sort_by: "task",
      order: "asc"
    }

    {:ok, actual_tasks} = Api.Service.list_tasks(query)
    assert actual_tasks |> Enum.count() == 1

    assert Api.Service.stop_task() == :ok

    {:ok, actual_tasks} = Api.Service.list_tasks(query)
    assert actual_tasks |> Enum.count() == 0

    assert Api.Service.start_task("new-task") == :ok

    {:ok, actual_tasks} = Api.Service.list_tasks(query)
    assert actual_tasks |> Enum.count() == 1

    assert Api.Service.update_task(
             Enum.at(actual_tasks, 0).id,
             %Api.TaskUpdate{start: start_time |> NaiveDateTime.add(-10 * 60, :second)}
           ) == :ok

    assert Api.Service.stop_task() == :ok

    {:ok, actual_tasks} = Api.Service.list_tasks(query)
    assert actual_tasks |> Enum.count() == 1
  end

  test "lists tasks" do
    tasks = Api.Fixtures.mock_tasks()
    stream = Api.Fixtures.mock_tasks_stream(tasks)
    actual_tasks = Api.Service.flatten(stream) |> Aggregate.Tasks.as_list()

    actual_tasks |> Enum.map(fn task -> assert Api.Service.add_task(task) == :ok end)

    start_time = Enum.at(actual_tasks, 0).start

    query = %Api.Query{
      from: start_time |> NaiveDateTime.add(-90 * 60, :second),
      to: start_time |> NaiveDateTime.add(90 * 60, :second),
      sort_by: "task",
      order: "asc"
    }

    {:ok, actual_tasks} = Api.Service.list_tasks(query)
    assert actual_tasks |> Enum.count() == 4
  end

  test "lists overlapping tasks" do
    tasks = Api.Fixtures.mock_tasks()
    stream = Api.Fixtures.mock_tasks_stream(tasks)
    actual_tasks = Api.Service.flatten(stream) |> Aggregate.Tasks.as_list()

    actual_tasks |> Enum.map(fn task -> assert Api.Service.add_task(task) == :ok end)

    {:ok, overlapping_tasks} = Api.Service.list_overlapping_tasks()

    assert overlapping_tasks |> Enum.count() == 1
  end

  test "retrieves duration aggregation" do
    tasks = Api.Fixtures.mock_tasks()
    stream = Api.Fixtures.mock_tasks_stream(tasks)
    actual_tasks = Api.Service.flatten(stream) |> Aggregate.Tasks.as_list()

    actual_tasks |> Enum.map(fn task -> assert Api.Service.add_task(task) == :ok end)

    start_time = Enum.at(actual_tasks, 0).start

    query = %Api.Query{
      from: start_time |> NaiveDateTime.add(-90 * 60, :second),
      to: start_time |> NaiveDateTime.add(90 * 60, :second),
      sort_by: "task",
      order: "asc"
    }

    {:ok, aggregation} = Api.Service.get_duration_aggregation(query)

    assert aggregation |> Enum.count() == 3
  end

  test "retrieves period aggregation" do
    tasks = Api.Fixtures.mock_tasks()
    stream = Api.Fixtures.mock_tasks_stream(tasks)
    actual_tasks = Api.Service.flatten(stream) |> Aggregate.Tasks.as_list()

    actual_tasks |> Enum.map(fn task -> assert Api.Service.add_task(task) == :ok end)

    start_time = Enum.at(actual_tasks, 0).start

    query = %Api.Query{
      from: start_time |> NaiveDateTime.add(-90 * 60, :second),
      to: start_time |> NaiveDateTime.add(90 * 60, :second),
      sort_by: "task",
      order: "asc"
    }

    {:ok, aggregation} = Api.Service.get_period_aggregation(query, :day)

    assert aggregation |> Enum.count() == 1
  end

  test "retrieves tasks aggregation" do
    tasks = Api.Fixtures.mock_tasks()
    stream = Api.Fixtures.mock_tasks_stream(tasks)
    actual_tasks = Api.Service.flatten(stream) |> Aggregate.Tasks.as_list()

    actual_tasks |> Enum.map(fn task -> assert Api.Service.add_task(task) == :ok end)

    start_time = Enum.at(actual_tasks, 0).start

    query = %Api.Query{
      from: start_time |> NaiveDateTime.add(-90 * 60, :second),
      to: start_time |> NaiveDateTime.add(90 * 60, :second),
      sort_by: "task",
      order: "asc"
    }

    {:ok, aggregation} = Api.Service.get_task_aggregation(query, ~r/.*/, :day)

    assert aggregation |> Enum.count() == 1
  end

  test "processes commands" do
    assert Api.Service.process_command("store", ["clear"]) == :ok

    assert Api.Service.process_command("store", ["invalid-command"]) ==
             {:error, "Command [invalid-command] is not supported"}

    assert Api.Service.process_command("invalid-service", ["clear"]) ==
             {:error, "Service [invalid-service] not found"}
  end
end
