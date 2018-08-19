defmodule Api.TaskUpdate do
  @moduledoc """
  Structure defining all fields of a task that can be updated.

  - `task` - task name
  - `start` - `NaiveDateTime` timestamp (UTC); task start date/time
  - `duration` - task duration, in minutes since `start`
  """

  defstruct [:task, :start, :duration]
end
