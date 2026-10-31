---
name: task
description: Pick up one task from the user's Backlog.md board in ~/Code/tasks, by number, name, or description, read its context, and take the next step for its column — propose a plan for To Do, find the live session or where work stopped for In Progress, check whether a Waiting task is still blocked and how to unblock it, or confirm a Done task. Use when the user runs /task or asks to pick up, resume, or check on a specific task.
---

# Task

The user names one task, such as `/task 7`, `/task TASK-7`, or
`/task local telemetry guard`. Find it, learn where it stands, and take the
next step its column calls for. Unlike `/backlog-triage`, this skill can go on
to do the work, but only after the user confirms the plan.

Use the board in `~/Code/tasks`. Pass `BACKLOG_CWD=~/Code/tasks` on every
`backlog` command, and change tasks only through `backlog` commands. Run
`BACKLOG_CWD=~/Code/tasks ~/.agents/bin/backlog-md-sync --pull` before
finding the task, and `BACKLOG_CWD=~/Code/tasks ~/.agents/bin/backlog-md-sync`
after updating it, as the task-tracking rule's Syncing section describes.

## 1. Find the task

```sh
BACKLOG_CWD=~/Code/tasks backlog task view TASK-7 --plain
BACKLOG_CWD=~/Code/tasks backlog search "local telemetry" --plain
```

- A bare number or `TASK-N` is an ID; view it directly.
- Anything else is a search. Search all columns, Done included. If one task
  clearly matches, use it. If several could, list them with their IDs and
  columns, and ask which one. If none matches, say so and offer to create it
  in To Do.

Read the whole task: description, acceptance criteria, implementation plan,
notes, final summary, references, dependencies, and labels. A task labeled
`agent` holds a delegated brief in its implementation plan.

## 2. Investigate before reporting

Check the task's current state with read-only lookups, in parallel where you
can. Follow its references and notes:

- **Pull requests:** open, merged, or closed; review state; failing checks;
  whether it's in a merge queue or set to auto-merge. `gh pr view` misses
  merge-queue entries, so use the GraphQL query in the `backlog-triage`
  skill's "Merge queue and auto-merge" section. Use the GitHub account your
  instructions specify for that repository.
- **Code:** the task's repository, its branches and grove worktrees, and
  whether the default branch already has the change.
- **People:** whether a Slack thread or email it mentions got a reply, using
  chat and mail MCP servers when they're available.
- **Other tasks:** whether a dependency or duplicate on the board is Done.

Resolve bare numbers like `app#1234` to full URLs. Note anything you
couldn't check, and why, rather than guessing.

## 3. Report, then follow the task's column

Start with a short card:

```
### TASK-7 · Stop sending telemetry from local dev stacks
In Progress · app · bug · last updated 2026-10-20

Links: [acme/app#5678](https://github.com/acme/app/pull/5678) ·
[telemetry.py](https://github.com/acme/app/blob/main/backend/telemetry.py)

Goal: One or two sentences on what the task is for.

State: What the investigation found, with its evidence.
```

Mark links you found that aren't on the task yet with "(new)". Then continue
with the section for the task's column.

### To Do

The next step is the user's, and no one is working on it. Propose a plan and
wait for confirmation before changing anything.

- If the task no longer needs doing, such as already fixed on the default
  branch, superseded, or duplicated, say so and recommend closing or dropping
  it instead.
- Otherwise, give numbered next steps: the repository and folder (or grove
  worktree), the branch, the approach, and the validation you'll run. If the
  task has an `agent` brief, base the plan on it.
- If the next step isn't code, such as replying to someone, say what it is
  and offer to draft the reply.

End your turn and wait. Once the user confirms, set the task In Progress and
do the work, following the task-tracking rule and any repository
instructions.

### In Progress

Someone may already be working on it. Before touching anything, look for an
agent session on the task:

```sh
~/.agents/bin/backlog-task-sessions TASK-7          # last 14 days
~/.agents/bin/backlog-task-sessions TASK-7 --days 60
```

It searches Copilot CLI, Claude Code, and Zed sessions for the task ID and
prints one tab-separated line per session, newest first: agent, status, last
activity, folder, title, and session ID. Status is `live` for a running
Copilot session, `recent` for activity in the last 15 minutes, and `idle`
otherwise. Claude Code and Zed sessions are never reported `live`, so treat a
`recent` one as possibly active.

- Ignore your own session: the one whose latest message is this request.
- A match only means the session mentions the ID. Board listings and triage
  passes mention many tasks, so judge from the title and folder which
  sessions actually worked on this one. Widen with `--days 60` if nothing
  fits.
- If a session is `live`, or `recent` and plausibly active, report it and
  stop. Don't start parallel work; suggest the user switch to that session.

Otherwise, work out where the task stopped. Combine the task's notes, its git
state (branches, worktrees, uncommitted changes, unpushed commits, open pull
requests), and the newest relevant session's last steps:

- **Copilot:** the newest file in `~/.copilot/session-state/ID/checkpoints/`,
  then the tail of `events.jsonl` in the same folder.
- **Claude Code:** the tail of `~/.claude/projects/*/ID.jsonl`.
- **Zed:** the thread's `detailed_summary` and last messages:

  ```sh
  sqlite3 -readonly ~/Library/Application\ Support/Zed/threads/threads.db \
    "select hex(data) from threads where id='ID'" | xxd -r -p | zstd -dq |
    jq '{detailed_summary, last: .messages[-3:]}'
  ```

Report what was done, what's left, and anything half-finished, such as
uncommitted changes. Then propose numbered next steps and wait for
confirmation before resuming, as for To Do. If the work turns out to be
blocked on someone else, or already landing, recommend moving it to Waiting
or keeping it In Progress with a note, instead.

### Waiting

The next step belongs to someone or something else. Find out what, from the
notes and references, then check whether it still is:

- **Resolved:** the pull request merged, the person replied, or the
  dependency is Done. Recommend Done if nothing's left, or To Do with the
  next step if the reply needs action.
- **Still waiting on a check or the pull request itself:** look for a way to
  unblock it. A failing check might be a flake to re-run or a fix to make; a
  branch might need updating; a required review might have no reviewer
  assigned. Propose the fix and wait for confirmation, since it means acting
  on the task.
- **Still waiting on a person:** say who, what they were asked, and how long
  ago. Read the thread first, through chat or mail MCP servers, in case
  the answer came somewhere unexpected, such as a canvas comment or another
  channel. If it's been long enough to chase, suggest who to poke and draft
  the message for the user to post. Chasing is the user's move, so recommend
  moving the task to To Do.

Never post, re-request review, or message anyone without asking first, as
the "Posting on My Behalf" rules describe. Never write through the Slack MCP
server; give the user the text instead.

### Done

Usually nothing's left. Show the final summary and confirm the evidence
still holds, such as the pull request being merged and not reverted. If the
notes promised follow-ups, check whether they're on the board, and offer to
add any that aren't. If the work turns out unfinished, say why and recommend
reopening it.

## 4. Update the board

- Add missing links as you find them, titled as the task-tracking rule
  describes: one `--add-ref` per bare URL, plus a `Links:` note with a
  `- Title: URL` line for each.
- Append a note for findings worth keeping, starting with today's date, such
  as `2026-10-22: PR approved; waiting on the types gate`.
- Change the task's column only after the user agrees, then record why in
  the same command.
