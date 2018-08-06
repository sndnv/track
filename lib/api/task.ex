defmodule Api.Task do
  @moduledoc false

  @derive [Poison.Encoder]
  defstruct [:id, :task, :start, :duration]
end
