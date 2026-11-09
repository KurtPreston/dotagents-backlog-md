# backlog-md

A dotagents plugin for tracking all my work, coding and otherwise, in one [Backlog.md](https://github.com/MrLesk/Backlog.md) task board at `~/Code/tasks`.

- `rules/task-tracking.md` — tells agents when and how to update the board: before, during, and after any session that creates a branch or commit.
- `skills/backlog-triage/` — a daily `/backlog-triage` pass that first archives Done tasks completed before Monday at midnight in your local timezone, keeping this week's completions on the board. It retains tasks with uncertain completion dates and never ages out unfinished work. Next it surfaces `agent-failed` tasks with their last notes for a retry, take-over, or drop decision, then lists running agent claims with their time In Progress (flagging more than 24 hours as possibly stuck), then queued tasks with any unfinished dependency blockers. It reads the queue label from `backlog-sidequest mode`, and keeps queued and claimed work out of ordinary stale-priority and To Do decisions. It then raises each remaining high-priority To Do or In Progress task with no board change or working agent session in 3 days, asking whether to work it today, delegate it, or lower its priority. Finally it walks through every Waiting task with an agent, optionally followed by the remaining To Do tasks. For each, the agent summarizes the remaining work and checks its state, and you decide, after talking it through if you need more context: close it as done, drop it, move it to To Do when the next step is yours, keep it waiting, delegate it to an agent, or mark it in progress when its pull request is already queued to merge. Delegated tasks go through `/sidequest`.
- `skills/task/` — `/task <number, name, or description>` picks up one task. The agent finds it, reads its context and checks its links, then acts on its column: proposes a plan for To Do and waits for approval; for In Progress, looks for a session already working on it, or works out where the work stopped; for Waiting, checks whether it's still blocked, looks for a way to unblock it, and suggests who to chase; for Done, confirms nothing's left.
- `skills/sidequest/` — `/sidequest [--now | --queue | --handoff] [task or description]` hands work to an agent. It finds or creates the task, writes a self-contained brief into its Implementation Plan, then acts on this machine's [delegation mode](#delegating-to-agents).
- `skills/weekly-review/` — `/weekly-review` runs a weekly retrospective. The agent gathers the week from the board and its git history, agent sessions, pull requests, and any chat, calendar, ticket, or planning servers the user's instructions list. It assesses what got done, what moved fast or stalled and why, and whether the work followed priorities. Then it recommends rule and skill changes, habits, and bigger shifts, checks last week's recommendations, saves the review as a board doc under `weekly-reviews/`, and hands picked tooling changes to `/sidequest`.
- `scripts/backlog-sidequest` — the script `/sidequest` uses to read the delegation mode, build the agent's prompt, and launch the configured agent CLI in the background with a log under `~/.local/state/backlog-md/sidequests/`.
- `scripts/backlog-task-sessions` — `backlog-task-sessions TASK-N [--days N]` lists Copilot CLI, Claude Code, and Zed sessions from the last 14 days that mention a task, newest first, flagging running Copilot sessions as `live`. `/task` uses it to avoid starting work that another session already has in hand.
- `scripts/backlog-agent-sessions` — `backlog-agent-sessions [--since YYYY-MM-DD | --days N]` lists every Copilot CLI, Claude Code, and Zed session active in a period, oldest first, with its client app, time span, prompt count, folder, and the tasks it named or touched. `backlog-agent-sessions prompts ID` prints one session's prompts. `/weekly-review` uses it to see where the week's agent time went and where agents needed correcting.
- `scripts/backlog-md-commit` — commits the task list's changes, with a message that Copilot CLI writes from the day's diff. It falls back to a plain list of changed tasks if Copilot fails, and does nothing when there are no changes. `--dry-run` prints the message without committing. When sync is on, it leaves commits to `backlog-md-sync`.
- `scripts/backlog-md-sync` — in [synced mode](#syncing-between-machines), commits each change with a plain message, then fetches, rebases, and pushes. `--pull` skips the push, and `setup` connects a machine's board to the remote. It does nothing when sync is off.
- `scripts/backlog-md-browser` — serves the web board on the port set in `config.jsonc`, for the browser launchd job. It exits with an error rather than switching ports when the port is taken.
- `scripts/backlog-md-schedule` — installs, removes, or inspects the launchd jobs: `backlog-md-commit` nightly at 23:55, or `backlog-md-sync` at login and every 15 minutes when sync is on, plus `backlog-md-browser` kept running unless the browser is turned off.
- `prompts/commit-message.md` — the instructions Copilot gets for the nightly commit message.
- `prompts/resolve-conflict.md` — the instructions Copilot gets when two machines edited the same task.
- `launchd/` — the job templates that `backlog-md-schedule` fills in.
- `lib/` — code the scripts share: reading `config.jsonc`, building sync commit messages, and resolving conflicts.
- `config.example.jsonc` — this machine's settings, copied to the git-ignored `config.jsonc`.
- `tests/run-agent-sessions-tests` — runs `backlog-agent-sessions` against fixture sessions for each agent in a temporary home folder, in about a second.
- `tests/run-sync-tests` — runs `backlog-md-sync` against a temporary remote and two boards standing in for two machines, in about 10 seconds.

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
```

The web board is always at http://localhost:6420/board, served by a launchd job that `backlog-md-schedule install` sets up. To change its port or turn it off, set `browser.port` or `browser.enabled` in `config.jsonc` and rerun `install`.

## Scheduling

The job runs through launchd, not cron. If the Mac is asleep at 23:55, cron skips that day's run, while launchd runs it once the Mac wakes. A missed or failed run loses nothing: the next one commits every change since the last commit.

A second job runs `backlog-md-browser` at login and restarts it within 30 seconds if it exits. Edits made in the web board are saved straight to the task files, and the commit or sync job picks them up.

`install` saves the current shell's PATH into the jobs, so launchd finds `node`, `backlog`, and `copilot` wherever they're installed. Rerun it after moving any of them, or after changing `config.jsonc`.

```sh
~/.agents/bin/backlog-md-schedule status   # Loaded state, last exit code, recent log lines
~/.agents/bin/backlog-md-schedule run      # Run it now through launchd
~/.agents/bin/backlog-md-schedule uninstall
```

The logs are at `~/Library/Logs/backlog-md-commit.log` and `~/Library/Logs/backlog-md-sync.log`.

## Syncing between machines

Synced mode keeps one board in step across several machines through a private git remote, such as a repository on a self-hosted git server. It's off by default. When it's on:

- Each change gets its own commit with a plain message such as `TASK-6 Board-sync: To Do → In Progress`, built from the task's ID and title. Short titles keep these readable.
- Agents pull at session start and before creating a task, and push after changing tasks. The launchd job also syncs at login and every 15 minutes, to pick up edits made in `backlog browser` and other machines' pushes.
- An unreachable remote isn't an error. Commits stay local until a later run pushes them.
- Backlog.md's `remote_operations` setting is on, so new task IDs account for tasks other machines have pushed.

Conflicts are resolved automatically where possible:

- **Duplicate IDs.** Two machines that create tasks while offline can both make `TASK-N`. The copy already on the remote keeps its ID. The local copy moves to the next free ID, and local tasks that depend on it follow. This is the one place the plugin edits task files directly, since Backlog.md has no renumber command.
- **Same task edited on two machines.** Copilot CLI merges the file, keeping both sides' notes and the most recent value of each field. The result is used only if it has no conflict markers, keeps the task's ID, and Backlog.md can still read it.
- **Anything else**, or a failed merge. The rebase is aborted, so the board shows this machine's version, and the script reports the files to resolve by hand with `git -C ~/Code/tasks pull --rebase`.

To turn it on, create an empty private repository on the remote and give each machine's SSH key push access. Then, on the machine whose board you want to keep:

```sh
cd ~/Code/dotagents/plugins/dotagents-backlog-md
cp config.example.jsonc config.jsonc       # set sync.enabled to true and sync.remote to the repository's SSH URL
~/.agents/bin/backlog-md-sync setup        # adds the remote and pushes the board
~/.agents/bin/backlog-md-schedule install  # switches to the sync job
```

On each other machine, write the same `config.jsonc` and run the same two commands. When `BACKLOG_CWD` doesn't exist yet, `setup` clones the board there. `setup` won't merge two boards that already have separate histories. Move the second one aside first and let `setup` clone.

## Delegating to agents

`/sidequest` writes the same brief whichever way the agent gets started: an Implementation Plan that starts with `Repo: owner/name` and `Branch: name` lines, then the goal, starting points, what done looks like, and the agent's limits. Set `delegation.mode` in `config.jsonc` to choose what happens next on each machine:

- `handoff` (the default) prints the folder and a prompt for you to start an agent yourself.
- `launch` starts an agent right away by running `delegation.command`, such as `["copilot", "-p", "{prompt}", "--allow-all-tools"]`, detached in the repository's checkout.
- `queue` adds the `delegation.label` label (default `agent`) and leaves the task in To Do for a program that watches the board, such as [docent](https://github.com/KurtPreston/docent)'s backlog work queue. Turn on sync so the watcher sees tasks you queue on another machine.

Only `queue` adds the label, so a watcher never starts a second agent on a task that was launched or handed off. `/sidequest --now`, `--queue`, or `--handoff` overrides the mode for one task.
