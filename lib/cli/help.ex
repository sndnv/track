defmodule Cli.Help do
  @moduledoc """
  Module used for generating application documentation and help messages.
  """

  @app "track"

  @brief "#{IO.ANSI.format([:bright, @app], true)} - Simple time/task tracking terminal utility"

  @description [
    "#{IO.ANSI.format([:bright, @app], true)} is a basic time/task tracking terminal-based application.",
    "It provides functionality for managing tasks and reporting on their duration and distribution."
  ]

  @supported_commands %{
    add: %{
      arguments: [],
      options: %{
        required: [
          [{"task", "Task name", ["Working on project", "dev", "bookkeeping"]}],
          [{"start-date", "Task start date", ["today", "today+2d", "today-1d", "1999-12-21"]}],
          [
            {"start-time", "Task start time",
             ["now", "now+10m", "now-90m", "now+3h", "now-1h", "23:45"]}
          ],
          [
            {"end-time", "Task end time",
             ["now", "now+10m", "now-90m", "now+3h", "now-1h", "23:45"]},
            {"duration", "Task duration", ["45m", "5h"]}
          ]
        ],
        optional: []
      },
      description: ["Adds a new task"]
    },
    remove: %{
      arguments: [
        {"<id>", "Task UUID", []}
      ],
      options: %{},
      description: ["Removes an existing task"]
    },
    update: %{
      arguments: [
        {"<id>", "Task UUID", []}
      ],
      options: %{
        required: [],
        optional: [
          [{"task", "Task name", ["Working on project", "dev", "bookkeeping"]}],
          [{"start-date", "Task start date", ["today", "today+2d", "today-1d", "1999-12-21"]}],
          [
            {"start-time", "Task start time",
             ["now", "now+10m", "now-90m", "now+3h", "now-1h", "23:45"]}
          ],
          [
            {"duration", "Task duration", ["45m", "5h"]}
          ]
        ]
      },
      description: [
        "Updates an existing task",
        "All parameters are optional but at least one is required"
      ]
    },
    start: %{
      arguments: [
        {"<task>", "Task name", ["Working on project", "dev", "bookkeeping"]}
      ],
      options: %{},
      description: [
        "Starts a new active task",
        "Only one active tasks is allowed; the currently active task can be stopped with '#{@app} stop'"
      ]
    },
    stop: %{
      arguments: [],
      options: %{},
      description: [
        "Stops an active task",
        "If the task's duration is under one minute, it is discarded."
      ]
    },
    list: %{
      arguments: [],
      options: %{
        required: [],
        optional: [
          [{"from", "Query start date", ["today", "today+2d", "today-1d", "1999-12-21"]}],
          [{"to", "Query end date", ["today", "today+2d", "today-1d", "1999-12-21"]}],
          [{"sort-by", "Field name to sort by", ["task", "start", "duration"]}],
          [{"order", "Sorting order", ["desc", "asc"]}]
        ]
      },
      description: [
        "Retrieves a list of all tasks based on the specified query parameters",
        "If no query parameters are supplied, today's tasks are retrieved, sorted by start time"
      ]
    },
    report: %{
      arguments: [
        {"duration", "Shows the total duration of each task for the queried period", []},
        {"day", "Shows daily distribution of tasks", []},
        {"week", "Shows weekly distribution of tasks", []},
        {"month", "Shows monthly distribution of tasks", []},
        {"task", "Shows total duration of the task(s) per day", []},
        {"overlap",
         "Shows all tasks that are overlapping and the day on which the overlap occurs", []}
      ],
      options: %{
        required: [],
        optional: [
          [{"from", "Query start date", ["today", "today+2d", "today-1d", "1999-12-21"]}],
          [{"to", "Query end date", ["today", "today+2d", "today-1d", "1999-12-21"]}],
          [{"sort-by", "Field name to sort by", ["task", "start", "duration"]}],
          [{"order", "Sorting order", ["desc", "asc"]}]
        ]
      },
      description: [
        "Generates reports",
        "If no query parameters are supplied, today's tasks are retrieved and processed"
      ]
    },
    service: %{
      arguments: [
        {"store clear", "Removes all stored tasks", []}
      ],
      options: %{},
      description: ["Executes management commands"]
    },
    legend: %{
      arguments: [],
      options: %{},
      description: [
        "Shows a colour legend with a brief description of what the various chart/table colours mean"
      ]
    },
    help: %{
      arguments: [],
      options: %{},
      description: ["Shows this help message"]
    }
  }

  @additional_options %{
    "--verbose": %{
      arguments: [],
      description: ["Enables extra logging"]
    },
    "--config": %{
      arguments: [{"file-path", "Path to custom config file", ["~/track/tasks.log"]}],
      description: [
        "Sets a custom config file",
        "The file should contain parameters in 'config_key=value' format; the only config key currently supported is 'log_file_path'"
      ]
    }
  }

  @examples %{
    add: %{
      description: "Adds a new task called 'dev', starting now with a duration of 30 minutes",
      examples: [
        "dev today now now+30m",
        "dev today now 30m",
        "--task dev --start-date today --start-time now --end-time now+30m",
        "--task dev --start-date today --start-time now --duration 30m",
        "task=dev start-date=today start-time=now end-time=now+30m",
        "task=dev start-date=today start-time=now duration=30m"
      ]
    },
    remove: %{
      description: "Removes an existing task with ID '56f3db20-...'",
      examples: [
        "56f3db20-88c9-44ba-a0f1-da78dc990b84"
      ]
    },
    update: %{
      description:
        "Updates an existing task with ID '56f3db20-...' to be called 'bookkeeping', starting yesterday with a duration of 45 minutes",
      examples: [
        "56f3db20-88c9-44ba-a0f1-da78dc990b84 bookkeeping today-1d 45m",
        "56f3db20-88c9-44ba-a0f1-da78dc990b84 --task bookkeeping --start-date today-1d --start-time now --duration 45m",
        "56f3db20-88c9-44ba-a0f1-da78dc990b84 task=bookkeeping start-date=today-1d start-time=now duration=45m"
      ]
    },
    start: %{
      description: "Starts a new active task called 'dev'",
      examples: [
        "dev"
      ]
    },
    stop: %{
      description: "Stops the currently active task",
      examples: [
        ""
      ]
    },
    list: %{
      description: "Lists all tasks in the last 30 days and sorts them by ascending duration",
      examples: [
        "today-30d today duration asc",
        "--from today-30d --to today --sort-by duration --order asc",
        "from=today-30d to=today sort-by=duration order=asc"
      ]
    },
    report: %{
      description:
        "Generates a report of the daily distribution of tasks, for all tasks in the last 10 and the next 5 days, with default sorting",
      examples: [
        "daily today-10d today+5d",
        "daily --from today-10d --to today+5d",
        "daily from=today-10d to=today+5d"
      ]
    },
    service: %{
      description: "Clears all tasks",
      examples: [
        "store clear"
      ]
    },
    legend: %{
      description: "Shows the colour legend",
      examples: [
        ""
      ]
    }
  }

  @default_padding 12
  @prefix "#{String.pad_leading("", @default_padding)} |"

  @doc """
  Generates the application's usage message.
  """

  def generate_usage_message() do
    generate_usage_from_attributes(@app, @supported_commands) |> Enum.join("\n")
  end

  @doc """
  Generates the application's help message.
  """

  def generate_help_message(for_command) do
    result =
      generate_help_message_from_attributes(
        @app,
        @brief,
        @description,
        @supported_commands,
        @additional_options,
        @examples,
        @prefix,
        for_command
      )

    case result do
      {:ok, message} -> {:ok, message |> Enum.join("\n\n")}
      error -> error
    end
  end

  @doc """
  Generates a usage message based on the supplied data.
  """

  def generate_usage_from_attributes(app, supported_commands) do
    commands = supported_commands |> Enum.map(fn {command, _} -> command end) |> Enum.sort()

    [
      "Usage:    #{app} <command> [arguments] [parameters]",
      "Commands: #{commands |> Enum.join(", ")}"
    ]
  end

  @doc """
  Generates a help message based on the supplied data.
  """

  def generate_help_message_from_attributes(
        app,
        brief,
        description,
        supported_commands,
        additional_options,
        examples,
        prefix,
        for_command \\ :all
      ) do
    {supported_commands, examples} =
      case for_command do
        :all ->
          {supported_commands, examples}

        command ->
          supported_commands =
            supported_commands |> Enum.filter(fn {k, _} -> k |> Atom.to_string() == command end)

          examples = examples |> Enum.filter(fn {k, _} -> k |> Atom.to_string() == command end)
          {supported_commands, examples}
      end

    brief = "\t#{brief}"

    description =
      description
      |> Enum.map(fn description_line -> "\t#{description_line}" end)
      |> Enum.join("\n")

    commands =
      supported_commands
      |> Enum.map(fn {command, data} ->
        command = command |> Atom.to_string()

        {simple_args, detailed_args} = arguments_to_string(data[:arguments], prefix)

        {simple_required_opts, detailed_required_opts} =
          options_to_string(data[:options][:required], "required", prefix)

        {simple_optional_opts, detailed_optional_opts} =
          options_to_string(data[:options][:optional], "optional", prefix)

        command_parameters = "#{simple_args}#{simple_required_opts}#{simple_optional_opts}"

        command_description = description_to_string(data[:description], prefix)

        command_overview = [
          "#{command |> String.pad_leading(@default_padding) |> add_style(:bright)} | #{
            command_description
          }",
          prefix,
          "#{prefix} $ #{app} #{command |> add_style(:bright)}#{command_parameters}"
        ]

        (command_overview ++ detailed_args ++ detailed_required_opts ++ detailed_optional_opts)
        |> Enum.join("\n")
      end)

    additional_options =
      additional_options
      |> Enum.map(fn {option, data} ->
        option = option |> Atom.to_string()
        {simple_args, detailed_args} = arguments_to_string(data[:arguments], prefix)

        option_description = description_to_string(data[:description], prefix)

        option_overview = [
          "#{option |> String.pad_leading(@default_padding) |> add_style(:bright)} | #{
            option_description
          }",
          prefix,
          "#{prefix} $ #{app} <command> [arguments] [parameters] #{option |> add_style(:bright)}#{
            simple_args
          }"
        ]

        (option_overview ++ detailed_args)
        |> Enum.join("\n")
      end)

    examples =
      examples
      |> Enum.map(fn {command, example_data} ->
        command = command |> Atom.to_string()

        alternatives =
          example_data[:examples]
          |> Enum.map(fn alternative ->
            "\t     $ #{app} #{command |> add_style(:bright)} #{alternative}"
          end)
          |> Enum.join("\n")

        "\t#{example_data[:description] |> add_style(:italic)}\n#{alternatives}"
      end)

    commands =
      case commands do
        [_ | _] -> ["Parameters" |> add_style(:bright) | commands]
        [] -> []
      end

    additional_options =
      case additional_options do
        [_ | _] -> ["Additional Options" |> add_style(:bright) | additional_options]
        [] -> []
      end

    examples =
      case examples do
        [_ | _] -> ["Examples" |> add_style(:bright) | examples]
        [] -> []
      end

    case commands do
      [_ | _] ->
        {
          :ok,
          ["Name" |> add_style(:bright), brief] ++
            ["Description" |> add_style(:bright), description] ++
            commands ++ additional_options ++ examples
        }

      [] ->
        {:error, "No help found for command [#{for_command}]"}
    end
  end

  @doc """
  Converts the supplied command description data to a string to be presented to the user.
  """

  def description_to_string(description, prefix) do
    case description do
      [primary | additional] ->
        primary = primary |> add_style(:italic)

        additional =
          additional
          |> Enum.map(fn description_line -> "#{prefix} #{description_line}" end)

        case additional do
          [_ | _] -> "#{primary}\n#{prefix}\n#{additional |> Enum.join("\n")}"
          [] -> primary
        end

      [] ->
        ""
    end
  end

  @doc """
  Converts the supplied arguments data to a string to be presented to the user.

  A tuple containing simple and detailed arguments is returned - `{simple, detailed}`.
  """

  def arguments_to_string(arguments, prefix) do
    simple_args = arguments |> Enum.map(fn {name, _, _} -> name end)

    simple_args =
      case simple_args do
        [_ | _] -> " #{simple_args |> Enum.join("|")}"
        [] -> ""
      end

    detailed_args =
      arguments
      |> Enum.map(fn {name, arg_description, examples} ->
        "#{prefix}   #{name |> String.pad_trailing(@default_padding)} - #{arg_description}#{
          examples |> examples_to_string
        }"
      end)

    detailed_args =
      case detailed_args do
        [_ | _] -> [prefix, "#{prefix} Arguments:" | detailed_args]
        [] -> []
      end

    {simple_args, detailed_args}
  end

  @doc """
  Converts the supplied options data to a string to be presented to the user.

  A tuple containing simple and detailed options is returned - `{simple, detailed}`.
  """

  def options_to_string(options, type, prefix) do
    simple_opts =
      (options || [])
      |> Enum.map(fn alternatives ->
        alternatives = alternatives |> Enum.map(fn {name, _, _} -> name end) |> Enum.join("|")

        case type do
          "required" -> " <#{alternatives}>"
          "optional" -> " [<#{alternatives}>]"
        end
      end)
      |> Enum.join("")

    detailed_opts =
      (options || [])
      |> Enum.flat_map(fn alternatives ->
        alternatives
        |> Enum.map(fn {name, alt_description, examples} ->
          "#{prefix}   --#{name |> String.pad_trailing(@default_padding)} - #{alt_description}#{
            examples |> examples_to_string
          }"
        end)
      end)

    detailed_opts =
      case detailed_opts do
        [_ | _] -> [prefix, "#{prefix} Options (#{type}):" | detailed_opts]
        [] -> []
      end

    {simple_opts, detailed_opts}
  end

  @doc """
  Converts the supplied examples list to a string to be presented to the user.
  """

  def examples_to_string(examples) do
    case examples do
      [_ | _] ->
        examples =
          examples
          |> Enum.map(fn example -> "\"#{example}\"" |> add_style(:italic) end)
          |> Enum.join(", ")

        " (e.g. #{examples})"

      [] ->
        ""
    end
  end

  @doc """
  Adds the specified ANSI style to the supplied string.
  """

  def add_style(string, style) do
    IO.ANSI.format([style, string], true)
  end
end
