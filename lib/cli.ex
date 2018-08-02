defmodule Cli do
  @moduledoc false

  # {app} action=add  task=development    start-date=2018-12-21     start-time=08:30    end-time=10:30 | duration=2h | event      #
  # {app} add         development         2018-12-21                08:30               10:30
  # {app} add         development         2018-12-21                08:30               2h
  # {app} add         development         2018-12-21                now                 start                                     # interactive?
  # {app} add         development         2018-12-21                now                 stop                                      # interactive?
  # {app} add         development         2018-12-21                now-2h              now+2h
  # {app} add         development         today                     now                                                           # start or stop (if interactive)
  # {app} add         development         [implicits: today, now, start | stop]
  # {app} add         dev[elopment]       [implicits]

  # {app} update      ???

  # {app} delete      ???

  # {app} list        ???

  # {app} stats       ???

  # {app} action=service    service=store         command=???
  # {app} service           store                 command=???
  # {app} service           api                   command=???
  # {app} service           aggregate             command=???

  # ... converted to ...

  # task(action, start-date, start-time, duration(in minutes))

end
