# Best practices

## Weekly Done retention

Keep Done focused on work completed in the current calendar week so recent
progress is easy to scan. At the start of `/backlog-triage`, automatically
archive Done tasks completed before Monday at 00:00 in the user's local
timezone. Use completion timing, not creation age; retain uncertain dates
and never archive unfinished work just because it is old. Archive through
the Backlog.md CLI so records, IDs, and links remain recoverable.

## Reports aren't done until read

A task whose output is a report, such as research or an audit, ends in To Do
with the `report` label, not in Done. Agents used to mark finished research
Done or Waiting, and the findings then sat unread or were archived with the
week's Done tasks. The label gives `/backlog-triage` and morning routines one
list of findings to read, and the user removes it once they've decided what
the report means.
