# backlog-md

A dotagents plugin for tracking all my work, coding and otherwise, in one [Backlog.md](https://github.com/MrLesk/Backlog.md) task board at `~/Code/tasks`.

- `rules/task-tracking.md` — tells agents when and how to update the board: before, during, and after any session that creates a branch or commit.
- `skills/backlog-triage/` — a daily `/backlog-triage` pass that walks through every Waiting task with an agent, then optionally every To Do task. For each, the agent summarizes the remaining work and checks its state, and you decide, after talking it through if you need more context: close it as done, drop it, move it to To Do when the next step is yours, keep it waiting, delegate it to an agent, or mark it in progress when its pull request is already queued to merge. Delegated tasks carry their brief in the task, and the agent can launch them at the end.
- `skills/task/` — `/task <number, name, or description>` picks up one task. The agent finds it, reads its context and checks its links, then acts on its column: proposes a plan for To Do and waits for approval; for In Progress, looks for a session already working on it, or works out where the work stopped; for Waiting, checks whether it's still blocked, looks for a way to unblock it, and suggests who to chase; for Done, confirms nothing's left.
- `scripts/backlog-task-sessions` — `backlog-task-sessions TASK-N [--days N]` lists Copilot CLI, Claude Code, and Zed sessions from the last 14 days that mention a task, newest first, flagging running Copilot sessions as `live`. `/task` uses it to avoid starting work that another session already has in hand.
- `scripts/backlog-md-commit` — commits the task list's changes, with a message that Copilot CLI writes from the day's diff. It falls back to a plain list of changed tasks if Copilot fails, and does nothing when there are no changes. `--dry-run` prints the message without committing.
- `scripts/backlog-md-schedule` — installs, removes, or inspects a launchd job that runs `backlog-md-commit` nightly at 23:55.
- `prompts/commit-message.md` — the instructions Copilot gets for the commit message.
- `launchd/backlog-md-commit.plist` — the job template that `backlog-md-schedule` fills in.

## Setup

```sh
brew install backlog-md
npm install -g @github/copilot   # then run `copilot login` once
cd ~/Code/dotagents && ./install.sh
~/.agents/bin/backlog-md-schedule install
```

`~/Code/tasks` is a git repository initialized with `backlog init`. Its `backlog/config.yml` sets the columns to `To Do`, `In Progress`, `Waiting`, and `Done`, with `To Do` as the default. Waiting holds tasks whose next step belongs to someone else, such as a pull request in review. It can also define projects, such as one per work repository, that other plugins' rules tell agents to use. Backlog.md allows only one ID prefix per board, so every task's ID still starts with `TASK-`.

`~/.localrc` sets the task list's location for interactive shells:

```sh
export BACKLOG_CWD=/Users/kurtpreston/Code/tasks
```

That makes plain `backlog` commands use it from any folder. It also overrides Backlog.md's usual per-folder lookup, so prefix `BACKLOG_CWD=.` to use a repository's own board. Agent shells and launchd don't load `~/.localrc`, so the rule has agents pass `BACKLOG_CWD` explicitly. `backlog-md-commit` reads only the `BACKLOG_CWD` line from `~/.localrc`, keeping its other secrets out of Copilot's environment, and falls back to `~/Code/tasks`.

## Usage

```sh
backlog task list --plain   # Text list, grouped by column
backlog board               # Kanban board in the terminal
backlog browser             # Web board at http://localhost:6420
```

## Scheduling

The job runs through launchd, not cron. If the Mac is asleep at 23:55, cron skips that day's run, while launchd runs it once the Mac wakes. A missed or failed run loses nothing: the next one commits every change since the last commit.

```sh
~/.agents/bin/backlog-md-schedule status   # Loaded state, last exit code, recent log lines
~/.agents/bin/backlog-md-schedule run      # Run it now through launchd
~/.agents/bin/backlog-md-schedule uninstall
```

The log is at `~/Library/Logs/backlog-md-commit.log`.
