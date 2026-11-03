---
name: sidequest
description: Hand a task to an agent without leaving the current work — find or create its task on the Backlog.md board in ~/Code/tasks, write a self-contained brief into it, then queue it for a board watcher, launch a background agent, or print a prompt to start one, as this machine's delegation mode says. Use when the user runs /sidequest, or asks to delegate, hand off, or assign a task to an agent, or to have an agent pick something up.
---

# Sidequest

Hand one piece of work to an agent so the user can stay on what they're doing.
The task on the board carries everything the agent needs, so any agent, on this
machine or another, can do it later without this conversation.

Use the board in `~/Code/tasks`. Pass `BACKLOG_CWD=~/Code/tasks` on every
`backlog` command, change tasks only through `backlog` commands, and follow the
task-tracking rule for titles, labels, projects, and links.

## Arguments

`/sidequest [--now | --queue | --handoff] [TASK-ID | description]`

- A task ID or title picks an existing task. A description names new work, or
  narrows which task the user means.
- With no argument, use the work just discussed in this conversation.
- `--now` launches immediately, `--queue` queues, and `--handoff` prints a
  prompt, overriding this machine's mode for this one task.

## 1. Find or create the task

```sh
BACKLOG_CWD=~/Code/tasks ~/.agents/bin/backlog-md-sync --pull
BACKLOG_CWD=~/Code/tasks backlog search "rename legacy module" --status "To Do,In Progress,Waiting" --plain
```

- If one open task clearly matches, use it. If several could, list them with
  their IDs and columns, and ask which one.
- If none matches, create one in To Do, labeled with its repository's name and
  with any `--project` the rules name for that repository.
- If the matching task is In Progress, someone may already be on it. Say so
  and ask before handing it off.

## 2. Write the brief

The task's Implementation Plan is the brief. It's everything the agent knows,
so write it for an agent with no knowledge of this conversation. It must start
with two lines that say where to work:

```markdown
Repo: acme/app
Branch: rename-legacy-module

Goal: …
```

- `Repo:` is the GitHub `owner/name`. `Branch:` is a new branch named per the
  branch-name rules, such as with a `compass-` prefix for Compass work in yolo.
- Then, briefly: the goal and why it matters; the files, pull requests,
  threads, and tasks to start from, as links; what's already known, so the
  agent doesn't redo it; what done looks like, such as a passing test or a
  draft pull request; and the limits. Limits include following the
  repository's AGENTS.md, and not merging or posting anything that needs the
  user's approval.
- If the task already has a brief, keep what still holds and add what this
  conversation learned, rather than replacing it.
- If the work would conflict with something still in progress, such as an
  open pull request touching the same files, make the task depend on that
  work's task with `--dep`, so the agent waits for it. `--dep` replaces the
  task's dependencies, so include any it already has.
- If the work is ambiguous, risky, or needs a decision only the user can make,
  say so and ask instead of handing it off.

Add the task's links as references, titled in a `Links:` note, per the
task-tracking rule.

## 3. Pick the mode

```sh
~/.agents/bin/backlog-sidequest mode
```

It prints this machine's `mode` and queue `label`, set under `delegation` in
the plugin's `config.jsonc`. A flag from the arguments overrides the mode.

| Mode | Who starts the agent | Task ends up in |
|------|----------------------|-----------------|
| `queue` | A board watcher, such as docent, on whichever machine runs it | To Do, with the label |
| `launch` | This machine, now, in the background | In Progress |
| `handoff` | The user, by pasting a prompt | To Do |

Only `queue` adds the label. In the other modes, remove it if the task has it,
so a watcher doesn't start a second agent on the same task. The examples below
use the default label, `agent`; use the configured one.

## 4. Hand it off

### queue

```sh
BACKLOG_CWD=~/Code/tasks backlog task edit TASK-7 -s "To Do" --add-label agent \
  --plan "$BRIEF" --append-notes "Sidequest: queued for an agent" --plain
```

A watcher starts the task once every task it depends on is Done. If any
aren't, say it will wait for them.

### launch

Find the folder to run in: the local checkout of the brief's `Repo:`. In a
grove-managed project, create the branch's worktree with
`grove path BRANCH --from BASE` and use that. If there's no local checkout, or
the task depends on unfinished tasks, don't launch; say why and offer `queue`
or `handoff` instead.

```sh
BACKLOG_CWD=~/Code/tasks backlog task edit TASK-7 -s "In Progress" --remove-label agent \
  --plan "$BRIEF" --plain
~/.agents/bin/backlog-sidequest launch TASK-7 ~/Code/app
BACKLOG_CWD=~/Code/tasks backlog task edit TASK-7 \
  --append-notes "Sidequest: launched in ~/Code/app, log at <log path>" --plain
```

The script runs the `command` from the config, such as the `copilot` or
`claude` CLI, detached in that folder, and prints its process ID and log path.

### handoff

```sh
BACKLOG_CWD=~/Code/tasks backlog task edit TASK-7 -s "To Do" --remove-label agent \
  --plan "$BRIEF" --append-notes "Sidequest: handed off for the user to start" --plain
~/.agents/bin/backlog-sidequest prompt TASK-7
```

Show the folder, found as for `launch`, and the prompt, in a code block the
user can copy.

Don't run the task as a sub-agent of this session in any mode. It would run
nested in this thread, where the user can't track it with their other agents,
and it would end when this session does.

## 5. Sync and report

```sh
BACKLOG_CWD=~/Code/tasks ~/.agents/bin/backlog-md-sync
```

Report in a few lines:

- The task as a link to its file, the `File:` path from `backlog task view`,
  with angle brackets around the path because it contains spaces.
- The mode, and what happens next. For `queue`, say what it waits on, if
  anything. For `launch`, give the log path, to follow with `tail -f`. For
  `handoff`, give the folder and prompt.

Then return to the work the user was doing.
