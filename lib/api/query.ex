defmodule Api.Query do
  @moduledoc """
  Structure defining task query options/filters.

  The following parameters are supported:
  - `:from` - `NaiveDateTime` timestamp; all entries *starting* before this date/time will be excluded
  - `:to` - `NaiveDateTime` timestamp; all entries *starting* after this date/time will be excluded
  - `:sort_by` - `Api.Task` field name to sort by; depending on the specific report/list, some fields may not be sortable
  - `:order` - `desc`ending (default) or `asc`ending
  """

  defstruct [:from, :to, :sort_by, :order]
end
