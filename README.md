# track
[![Travis](https://travis-ci.org/sndnv/track.svg?branch=master)](https://travis-ci.org/sndnv/track) [![Coverage Status](https://coveralls.io/repos/github/sndnv/track/badge.svg?branch=master)](https://coveralls.io/github/sndnv/track?branch=master) [![license](https://img.shields.io/github/license/sndnv/track.svg)]()

**track** is a terminal-based application for basic time/task tracking and reporting

## Getting started

Installing **track** involves only obtaining the executable and placing it in its desired location. All data created by the application will be stored in `track/tasks.log` under the user's home directory.

### Download or build

> Erlang/OTP needs to be installed

###### Download
The latest [escript executable](https://hexdocs.pm/mix/master/Mix.Tasks.Escript.Build.html) can be found in [releases](https://github.com/sndnv/track/releases).

###### Build

Running `MIX_ENV=prod mix escript.build` will create an escript executable called `track` in the project's folder.

### Install

The application can be started from any directory and will (by default) write all its data to `$HOME/track/tasks.log`.

For convenience, the following commands can be executed:

###### Linux:
```bash
# makes the application available to all users and runnable without full/relative path
sudo mv track /usr/local/bin/track

# generates the bash completion file
track generate

# moves the script to the bash_completion directory
sudo mv track.bash_completion /etc/bash_completion.d/track

# enables completion for the current session
source /etc/bash_completion.d/track
```

###### Mac:

> `bash-completion` is not available by default on Mac and will need to be installed first

```bash
# makes the application available to all users and runnable without full/relative path
sudo mv track /usr/local/bin/track

# generates the bash completion file
track generate

# moves the script to the bash_completion directory
sudo mv track.bash_completion /usr/local/etc/bash_completion.d/track

# enables completion for the current session
source /usr/local/etc/bash_completion.d/track
```

## Config

Currently, the only configurable parameter is the path to the tasks log.

The default log location is `$HOME/track/tasks.log`; in `dev` and `test`, all log files are placed under `<repo dir>/run/`.

The default config can be overridden by providing a custom config file: `track <command> [arguments] [parameters] --config <path to config file>`

###### Example config file
A file `$HOME/track/config` with the following content
```
log_file_path="$HOME/track/my_tasks.log"
```

can be used by calling: `track <command> [arguments] [parameters] --config $HOME/track/config`

## Usage

### Commands
```
         add | Adds a new task
             |
             | $ track add <task> <start-date> <start-time> <end-time|duration>
             |
             | Options (required):
             |   --task         - Task name (e.g. "Working on project", "dev", "bookkeeping")
             |   --start-date   - Task start date (e.g. "today", "today+2d", "today-1d", "1999-12-21")
             |   --start-time   - Task start time (e.g. "now", "now+10m", "now-90m", "now+3h", "now-1h", "23:45")
             |   --end-time     - Task end time (e.g. "now", "now+10m", "now-90m", "now+3h", "now-1h", "23:45")
             |   --duration     - Task duration (e.g. "45m", "5h")
```

```
    generate | Generates a bash_completion script
             |
             | $ track generate
```

```
        help | Shows this help message
             |
             | $ track help
```

```
      legend | Shows a colour legend with a brief description of what the various chart/table colours mean
             |
             | $ track legend
```

```
        list | Retrieves a list of all tasks based on the specified query parameters
             |
             | If no query parameters are supplied, today's tasks are retrieved, sorted by start time
             |
             | $ track list [<from>] [<to>] [<sort-by>] [<order>]
             |
             | Options (optional):
             |   --from         - Query start date (e.g. "today", "today+2d", "today-1d", "1999-12-21")
             |   --to           - Query end date (e.g. "today", "today+2d", "today-1d", "1999-12-21")
             |   --sort-by      - Field name to sort by (e.g. "task", "start", "duration")
             |   --order        - Sorting order (e.g. "desc", "asc")
```

```
      remove | Removes an existing task
             |
             | $ track remove <id>
             |
             | Arguments:
             |   <id>         - Task UUID
```

```
      report | Generates reports
             |
             | If no query parameters are supplied, today's tasks are retrieved and processed
             |
             | $ track report duration|day|week|month|task|overlap [<from>] [<to>] [<sort-by>] [<order>]
             |
             | Arguments:
             |   duration     - Shows the total duration of each task for the queried period
             |   day          - Shows daily distribution of tasks
             |   week         - Shows weekly distribution of tasks
             |   month        - Shows monthly distribution of tasks
             |   task         - Shows total duration of the task(s) per day
             |   overlap      - Shows all tasks that are overlapping and the day on which the overlap occurs
             |
             | Options (optional):
             |   --from         - Query start date (e.g. "today", "today+2d", "today-1d", "1999-12-21")
             |   --to           - Query end date (e.g. "today", "today+2d", "today-1d", "1999-12-21")
             |   --sort-by      - Field name to sort by (e.g. "task", "start", "duration")
             |   --order        - Sorting order (e.g. "desc", "asc")
```

```
     service | Executes management commands
             |
             | $ track service store clear
             |
             | Arguments:
             |   store clear  - Removes all stored tasks
```

```
       start | Starts a new active task
             |
             | Only one active tasks is allowed; the currently active task can be stopped with 'track stop'
             |
             | $ track start <task>
             |
             | Arguments:
             |   <task>       - Task name (e.g. "Working on project", "dev", "bookkeeping")
```

```
        stop | Stops an active task
             |
             | If the task's duration is under one minute, it is discarded.
             |
             | $ track stop
```

```
      update | Updates an existing task
             |
             | All parameters are optional but at least one is required
             |
             | $ track update <id> [<task>] [<start-date>] [<start-time>] [<duration>]
             |
             | Arguments:
             |   <id>         - Task UUID
             |
             | Options (optional):
             |   --task         - Task name (e.g. "Working on project", "dev", "bookkeeping")
             |   --start-date   - Task start date (e.g. "today", "today+2d", "today-1d", "1999-12-21")
             |   --start-time   - Task start time (e.g. "now", "now+10m", "now-90m", "now+3h", "now-1h", "23:45")
             |   --duration     - Task duration (e.g. "45m", "5h")

```

### Additional options

```
    --config | Sets a custom config file
             |
             | $ track <command> [arguments] [parameters] --config file-path
             |
             | Arguments:
             |   file-path    - Path to custom config file (e.g. "~/track/tasks.log")
```

```
   --verbose | Enables extra logging
             |
             | $ track <command> [arguments] [parameters] --verbose

```

### Examples
```
Adds a new task called 'dev', starting now with a duration of 30 minutes
     $ track add dev today now now+30m
     $ track add dev today now 30m
     $ track add --task dev --start-date today --start-time now --end-time now+30m
     $ track add --task dev --start-date today --start-time now --duration 30m
     $ track add task=dev start-date=today start-time=now end-time=now+30m
     $ track add task=dev start-date=today start-time=now duration=30m

Shows the colour legend
     $ track legend

Lists all tasks in the last 30 days and sorts them by ascending duration
     $ track list today-30d today duration asc
     $ track list --from today-30d --to today --sort-by duration --order asc
     $ track list from=today-30d to=today sort-by=duration order=asc

Removes an existing task with ID '56f3db20-...'
     $ track remove 56f3db20-...

Generates a report of the daily distribution of tasks
 for all tasks in the last 10 and the next 5 days, with default sorting
     $ track report daily today-10d today+5d
     $ track report daily --from today-10d --to today+5d
     $ track report daily from=today-10d to=today+5d

Clears all tasks
     $ track service store clear

Starts a new active task called 'dev'
     $ track start dev

Stops the currently active task
     $ track stop

Updates an existing task with ID '56f3db20-...' to be called 'bookkeeping',
 starting yesterday with a duration of 45 minutes
     $ track update 56f3db20-... bookkeeping today-1d 45m
     $ track update 56f3db20-... --task bookkeeping --start-date today-1d --start-time now --duration 45m
     $ track update 56f3db20-... task=bookkeeping start-date=today-1d start-time=now duration=45m

```

## Versioning
We use [SemVer](http://semver.org/) for versioning.

## License
This project is licensed under the Apache License, Version 2.0 - see the [LICENSE](LICENSE) file for details

> Copyright 2018 https://github.com/sndnv
>
> Licensed under the Apache License, Version 2.0 (the "License");
> you may not use this file except in compliance with the License.
> You may obtain a copy of the License at
>
> http://www.apache.org/licenses/LICENSE-2.0
>
> Unless required by applicable law or agreed to in writing, software
> distributed under the License is distributed on an "AS IS" BASIS,
> WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
> See the License for the specific language governing permissions and
> limitations under the License.
