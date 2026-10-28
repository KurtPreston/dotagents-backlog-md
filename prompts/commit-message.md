Write a git commit message for the day's changes to my personal task list.

The repository is a Backlog.md task board. Each file in `backlog/tasks/` is one task, with YAML front matter (`title`, `status`, `labels`, `priority`, `due_date`) and optional sections such as Implementation Notes and Final Summary. The statuses are To Do, In Progress, Waiting (the next step is someone else's, such as a pull request in review), and Done. Labels usually name the repository or area the task belongs to.

Format:

- First line: `Tasks for DATE: SUMMARY`, using the date given below, where SUMMARY is a few words on the day's main themes. Keep the whole line under 72 characters.
- Then a blank line.
- Then a short bulleted list, grouped by what happened: work completed, work started or still in progress, work now waiting on others, and new to-do items. Skip empty groups. Mention task IDs and titles, and fold in the substance of any final summaries or notes. Keep it to about 15 bullets at most.

Write only the commit message, as plain text. Don't wrap it in a code block, and don't add any preamble, explanation, or sign-off.
