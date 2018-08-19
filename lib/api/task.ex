defmodule Api.Task do
  @moduledoc """
  Structure defining all the fields of a task:

  - `id` - unique task identifier (UUID)
  - `task` - task name
  - `start` - `NaiveDateTime` timestamp (UTC); task start date/time
  - `duration` - task duration, in minutes since `start`
  """

  @derive [Poison.Encoder]
  defstruct [:id, :task, :start, :duration]
end
