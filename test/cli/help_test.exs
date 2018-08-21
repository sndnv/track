defmodule Cli.HelpTest do
  @moduledoc false

  use ExUnit.Case

  test "adds styles to strings" do
    assert Cli.Help.add_style("test", :bright) == [[[[] | "\e[1m"], "test"] | "\e[0m"]
    assert Cli.Help.add_style("test", :italic) == [[[[] | "\e[3m"], "test"] | "\e[0m"]
  end

  test "converts examples data to string" do
    test_examples = ["today", "today+2d", "today-1d", "1999-12-21"]

    expected_string =
      " (e.g. \e[3m\"today\"\e[0m, \e[3m\"today+2d\"\e[0m, \e[3m\"today-1d\"\e[0m, \e[3m\"1999-12-21\"\e[0m)"

    assert Cli.Help.examples_to_string(test_examples) == expected_string

    test_examples = []
    expected_string = ""
    assert Cli.Help.examples_to_string(test_examples) == expected_string
  end

  test "converts options data to string" do
    test_options = [
      [{"task", "Task name", ["Working on project", "dev", "bookkeeping"]}],
      [
        {"duration", "Task duration", ["45m", "5h"]},
        {"test", "Some alternative", []}
      ]
    ]

    expected_simple_string = " <task> <duration|test>"

    expected_detailed_string = [
      "|",
      "| Options (required):",
      "|   --task         - Task name (e.g. \e[3m\"Working on project\"\e[0m, \e[3m\"dev\"\e[0m, \e[3m\"bookkeeping\"\e[0m)",
      "|   --duration     - Task duration (e.g. \e[3m\"45m\"\e[0m, \e[3m\"5h\"\e[0m)",
      "|   --test         - Some alternative"
    ]

    {actual_simple_string, actual_detailed_string} =
      Cli.Help.options_to_string(test_options, "required", "|")

    assert actual_simple_string == expected_simple_string
    assert actual_detailed_string == expected_detailed_string

    expected_simple_string = " [<task>] [<duration|test>]"

    expected_detailed_string = [
      "|",
      "| Options (optional):",
      "|   --task         - Task name (e.g. \e[3m\"Working on project\"\e[0m, \e[3m\"dev\"\e[0m, \e[3m\"bookkeeping\"\e[0m)",
      "|   --duration     - Task duration (e.g. \e[3m\"45m\"\e[0m, \e[3m\"5h\"\e[0m)",
      "|   --test         - Some alternative"
    ]

    {actual_simple_string, actual_detailed_string} =
      Cli.Help.options_to_string(test_options, "optional", "|")

    assert actual_simple_string == expected_simple_string
    assert actual_detailed_string == expected_detailed_string

    test_options = %{}
    expected_simple_string = ""
    expected_detailed_string = []

    {actual_simple_string, actual_detailed_string} =
      Cli.Help.options_to_string(test_options, "optional", "|")

    assert actual_simple_string == expected_simple_string
    assert actual_detailed_string == expected_detailed_string
  end

  test "converts arguments data to string" do
    test_arguments = [
      {"<task>", "Task name", ["Working on project", "dev", "bookkeeping"]},
      {"<test>", "Test argument", []}
    ]

    expected_simple_string = " <task>|<test>"

    expected_detailed_string = [
      "|",
      "| Arguments:",
      "|   <task>       - Task name (e.g. \e[3m\"Working on project\"\e[0m, \e[3m\"dev\"\e[0m, \e[3m\"bookkeeping\"\e[0m)",
      "|   <test>       - Test argument"
    ]

    {actual_simple_string, actual_detailed_string} =
      Cli.Help.arguments_to_string(test_arguments, "|")

    assert actual_simple_string == expected_simple_string
    assert actual_detailed_string == expected_detailed_string

    test_arguments = []
    expected_simple_string = ""
    expected_detailed_string = []

    {actual_simple_string, actual_detailed_string} =
      Cli.Help.arguments_to_string(test_arguments, "|")

    assert actual_simple_string == expected_simple_string
    assert actual_detailed_string == expected_detailed_string
  end

  test "converts description data to string" do
    test_description = [
      "Starts a new active task",
      "Only one active tasks is allowed"
    ]

    expected_string = "\e[3mStarts a new active task\e[0m\n|\n| Only one active tasks is allowed"
    actual_string = Cli.Help.description_to_string(test_description, "|")
    assert actual_string == expected_string

    test_description = [
      "Starts a new active task"
    ]

    expected_string = [[[[] | "\e[3m"], "Starts a new active task"] | "\e[0m"]
    actual_string = Cli.Help.description_to_string(test_description, "|")
    assert actual_string == expected_string

    test_description = []

    expected_string = ""
    actual_string = Cli.Help.description_to_string(test_description, "|")
    assert actual_string == expected_string
  end

  test "converts attributes to a help message" do
    test_app = "test_help"

    test_brief = "test_brief"

    test_description = ["test", "help", "sample description"]

    test_commands = %{
      start: %{
        arguments: [
          {"<task>", "Task name", ["Working on project", "dev", "bookkeeping"]}
        ],
        options: %{},
        description: [
          "Starts a new active task",
          "Only one active tasks is allowed"
        ]
      },
      stop: %{
        arguments: [],
        options: %{},
        description: []
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
          "Test Description #1",
          "Test Description #2"
        ]
      }
    }

    test_additional_options = %{
      "--verbose": %{
        arguments: [],
        description: ["Enables extra logging"]
      },
      "--config": %{
        arguments: [{"file-path", "Path to custom config file", ["~/track/tasks.log"]}],
        description: [
          "Description Line #1",
          "Description Line #2"
        ]
      }
    }

    test_examples = %{
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
        description: "Test Description #3",
        examples: [
          "today-30d today duration asc",
          "--from today-30d --to today --sort-by duration --order asc",
          "from=today-30d to=today sort-by=duration order=asc"
        ]
      }
    }

    expected_string = [
      [[[[] | "\e[1m"], "Name"] | "\e[0m"],
      "\ttest_brief",
      [[[[] | "\e[1m"], "Description"] | "\e[0m"],
      "\ttest\n\thelp\n\tsample description",
      [[[[] | "\e[1m"], "Parameters"] | "\e[0m"],
      "\e[1m        list\e[0m | \e[3mTest Description #1\e[0m\n|\n| Test Description #2\n|\n| $ test_help \e[1mlist\e[0m [<from>] [<to>] [<sort-by>] [<order>]\n|\n| Options (optional):\n|   --from         - Query start date (e.g. \e[3m\"today\"\e[0m, \e[3m\"today+2d\"\e[0m, \e[3m\"today-1d\"\e[0m, \e[3m\"1999-12-21\"\e[0m)\n|   --to           - Query end date (e.g. \e[3m\"today\"\e[0m, \e[3m\"today+2d\"\e[0m, \e[3m\"today-1d\"\e[0m, \e[3m\"1999-12-21\"\e[0m)\n|   --sort-by      - Field name to sort by (e.g. \e[3m\"task\"\e[0m, \e[3m\"start\"\e[0m, \e[3m\"duration\"\e[0m)\n|   --order        - Sorting order (e.g. \e[3m\"desc\"\e[0m, \e[3m\"asc\"\e[0m)",
      "\e[1m       start\e[0m | \e[3mStarts a new active task\e[0m\n|\n| Only one active tasks is allowed\n|\n| $ test_help \e[1mstart\e[0m <task>\n|\n| Arguments:\n|   <task>       - Task name (e.g. \e[3m\"Working on project\"\e[0m, \e[3m\"dev\"\e[0m, \e[3m\"bookkeeping\"\e[0m)",
      "\e[1m        stop\e[0m | \n|\n| $ test_help \e[1mstop\e[0m",
      [[[[] | "\e[1m"], "Additional Options"] | "\e[0m"],
      "\e[1m    --config\e[0m | \e[3mDescription Line #1\e[0m\n|\n| Description Line #2\n|\n| $ test_help <command> [arguments] [parameters] \e[1m--config\e[0m file-path\n|\n| Arguments:\n|   file-path    - Path to custom config file (e.g. \e[3m\"~/track/tasks.log\"\e[0m)",
      "\e[1m   --verbose\e[0m | \e[3mEnables extra logging\e[0m\n|\n| $ test_help <command> [arguments] [parameters] \e[1m--verbose\e[0m",
      [[[[] | "\e[1m"], "Examples"] | "\e[0m"],
      "\t\e[3mTest Description #3\e[0m\n\t     $ test_help \e[1mlist\e[0m today-30d today duration asc\n\t     $ test_help \e[1mlist\e[0m --from today-30d --to today --sort-by duration --order asc\n\t     $ test_help \e[1mlist\e[0m from=today-30d to=today sort-by=duration order=asc",
      "\t\e[3mStarts a new active task called 'dev'\e[0m\n\t     $ test_help \e[1mstart\e[0m dev",
      "\t\e[3mStops the currently active task\e[0m\n\t     $ test_help \e[1mstop\e[0m "
    ]

    {:ok, actual_string} =
      Cli.Help.generate_help_message_from_attributes(
        test_app,
        test_brief,
        test_description,
        test_commands,
        test_additional_options,
        test_examples,
        "|"
      )

    assert actual_string == expected_string

    expected_string = [
      [[[[] | "\e[1m"], "Name"] | "\e[0m"],
      "\ttest_brief",
      [[[[] | "\e[1m"], "Description"] | "\e[0m"],
      "\ttest\n\thelp\n\tsample description",
      [[[[] | "\e[1m"], "Parameters"] | "\e[0m"],
      "\e[1m        stop\e[0m | \n|\n| $ test_help \e[1mstop\e[0m",
      [[[[] | "\e[1m"], "Additional Options"] | "\e[0m"],
      "\e[1m    --config\e[0m | \e[3mDescription Line #1\e[0m\n|\n| Description Line #2\n|\n| $ test_help <command> [arguments] [parameters] \e[1m--config\e[0m file-path\n|\n| Arguments:\n|   file-path    - Path to custom config file (e.g. \e[3m\"~/track/tasks.log\"\e[0m)",
      "\e[1m   --verbose\e[0m | \e[3mEnables extra logging\e[0m\n|\n| $ test_help <command> [arguments] [parameters] \e[1m--verbose\e[0m",
      [[[[] | "\e[1m"], "Examples"] | "\e[0m"],
      "\t\e[3mStops the currently active task\e[0m\n\t     $ test_help \e[1mstop\e[0m "
    ]

    {:ok, actual_string} =
      Cli.Help.generate_help_message_from_attributes(
        test_app,
        test_brief,
        test_description,
        test_commands,
        test_additional_options,
        test_examples,
        "|",
        "stop"
      )

    assert actual_string == expected_string

    {:error, error_message} =
      Cli.Help.generate_help_message_from_attributes(
        test_app,
        test_brief,
        test_description,
        test_commands,
        test_additional_options,
        test_examples,
        "|",
        "invalid"
      )

    assert error_message == "No help found for command [invalid]"
  end

  test "converts attributes to a usage message" do
    test_app = "test_help"

    test_commands = %{
      start: %{
        arguments: [
          {"<task>", "Task name", ["Working on project", "dev", "bookkeeping"]}
        ],
        options: %{},
        description: [
          "Starts a new active task",
          "Only one active tasks is allowed"
        ]
      },
      stop: %{
        arguments: [],
        options: %{},
        description: []
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
          "Test Description #1",
          "Test Description #2"
        ]
      }
    }

    expected_string = [
      "Usage:    test_help <command> [arguments] [parameters]",
      "Commands: list, start, stop"
    ]

    actual_string = Cli.Help.generate_usage_from_attributes(test_app, test_commands)

    assert actual_string == expected_string
  end
end
