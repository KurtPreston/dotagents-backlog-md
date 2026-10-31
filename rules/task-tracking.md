## Task Tracking

I keep one task list for all my work, coding and otherwise, in `~/Code/tasks`. It's managed with [Backlog.md](https://github.com/MrLesk/Backlog.md) (the `backlog` CLI), and it's how I see at a glance what's left to do, what's in progress, and what I'm waiting on.

Run `backlog` from any project by pointing it at that folder, and pass `--plain` for readable text output. My interactive shells set `BACKLOG_CWD` in `~/.localrc`, but agent shells may not load it, so always pass it explicitly:

```sh
BACKLOG_CWD=~/Code/tasks backlog task list --plain
BACKLOG_CWD=~/Code/tasks backlog search "backlog plugin" --status "To Do,In Progress,Waiting" --plain
BACKLOG_CWD=~/Code/tasks backlog task create "Add backlog-md plugin" -s "In Progress" -l dotagents --plain
BACKLOG_CWD=~/Code/tasks backlog task edit TASK-7 --append-notes "Scheduled with launchd, not cron" --plain
BACKLOG_CWD=~/Code/tasks backlog task edit TASK-7 --add-ref https://github.com/acme/app/pull/1234 --append-notes "Links:
- Fix the docs site build: https://github.com/acme/app/pull/1234" --plain
BACKLOG_CWD=~/Code/tasks backlog task edit TASK-7 -s Done --final-summary "Added the plugin and nightly commit job." --plain
```

- Change tasks only through `backlog` commands, not by editing the files, so their metadata stays valid.
- Give each task a short title of about six words or fewer that names the work, such as "Sync task board across machines". The title becomes the task's filename and appears in every commit about the task.
- Never `git commit` in `~/Code/tasks` by hand. Scripts commit it, as described under Syncing.
- If a sandbox blocks writing to `~/Code/tasks`, ask me for access rather than skipping the update.

### Syncing

The board may be synced between my machines through a private git remote. Sync the board at these points:

```sh
BACKLOG_CWD=~/Code/tasks ~/.agents/bin/backlog-md-sync --pull   # once at session start, before first reading the board, and before creating a task
BACKLOG_CWD=~/Code/tasks ~/.agents/bin/backlog-md-sync          # after changing tasks, once the batch of edits is done
```

The script does nothing when sync is off, so run it either way. When the remote is unreachable, it says so and exits successfully; carry on, since a later run pushes the changes. When it reports a conflict it couldn't merge, tell me, and leave the board as it is rather than resolving it with git yourself.

The columns are:

- **To Do** — the next step is mine, but no one is working on it: work not started yet, or deferred partway.
- **In Progress** — being worked on now.
- **Waiting** — the next step belongs to someone or something else, such as a pull request in review, a question out to another person, or another task it depends on.
- **Done** — finished.

What decides between To Do and Waiting is whose move it is. A pull request with review comments to answer, or a person who needs chasing, is my move, so it goes in To Do.

### Links

Attach a task's pertinent links as references, so whoever picks it up later can open them without searching: its pull requests and issues, the Slack thread or email it came from or waits on, and key docs. Use full URLs, not bare numbers like `app#1234`. Pass `--ref` on create and `--add-ref` on edit, and add links as they appear, such as when a pull request is opened.

Make each reference the bare URL and nothing else. The web UI only links a reference whose whole value is a URL, and `backlog` drops YAML comments whenever it rewrites a task, so a title can't live in the reference.

Title each link in the task's notes instead, so a reader can tell links apart without opening them, such as several Slack canvases whose URLs look alike. Append a `Links:` block with one `- Title: URL` line per link in the same edit that adds the reference, as in the `--add-ref` example above. Write the line breaks literally inside the quotes. Use the page's own title, such as a pull request or issue title, a thread's subject, or a document's name, and write a short description when there isn't one.

- `backlog` splits reference values on commas, so repeat the flag for each link instead of joining links with commas.

### When to Update It

Track any session that creates a branch or commit. Questions, reviews, and exploration that don't produce one don't need a task.

1. **Before starting**, search for a matching open task and reuse it. Otherwise create one. Set it to In Progress and label it with the repository's name, such as `-l dotagents`. Pass `--project` too when another rule names a project for the repository.
2. **During the work**, append notes for decisions and state worth keeping, especially before stopping partway. Record deferred work, review findings you didn't fix, and promised follow-ups as new To Do tasks instead of leaving them only in the conversation. Give each new task the links it came from.
3. **When finishing**, set the task to Done with a one- or two-sentence final summary. If it's waiting on someone else, such as a pull request in review, move it to Waiting, add the pull request as a reference, and note who or what it's waiting on. If it's unfinished, leave it In Progress with a note on where it stopped.

When I mention something non-code I need to do, such as replying to someone or filing paperwork, offer to add it as a To Do task. Label it (e.g. `errand` or `admin`), pass `--due-date YYYY-MM-DD` when it has a deadline, and attach any thread or document it relates to.
