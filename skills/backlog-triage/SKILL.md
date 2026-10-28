---
name: backlog-triage
description: Walk the user through every Waiting task on their Backlog.md board in ~/Code/tasks, then optionally their To Do tasks, one at a time, and decide each one's fate — close as done, drop, move to To Do, keep waiting, delegate to an agent, or mark in progress. Use when the user runs /backlog-triage or asks to triage, review, or clean up their board or what they're waiting on.
---

# Backlog Triage

Waiting holds tasks whose next step belongs to someone else: pull requests in
review, questions out to other people, work blocked on another task. Left
alone, it fills with things that already came back or quietly stalled. This
skill is a short daily pass that gives every Waiting task a decision, then
offers the same pass over To Do.

Your job is to investigate and recommend, not to do the work. Don't fix,
merge, or post anything during triage. The only work that starts is what the
user delegates, and it starts as soon as they delegate it.

Use the board in `~/Code/tasks`. Pass `BACKLOG_CWD=~/Code/tasks` on every
`backlog` command, and change tasks only through `backlog` commands.

## 1. Load the Waiting column

```sh
BACKLOG_CWD=~/Code/tasks backlog task list -s Waiting --json
BACKLOG_CWD=~/Code/tasks backlog task view TASK-N --plain
```

View every task in full. If the column is empty, say so and go to
[the To Do pass](#6-the-to-do-pass).

Order them oldest first (lowest ID), except that a task comes before any
task in the pass that depends on it, so blockers are decided first.

## 2. Investigate before asking

Before presenting the first task, check every task's current state with
read-only lookups, in parallel where you can. Follow each task's references
and notes:

- **Pull requests:** merged, closed, approved, changes requested, failing
  checks, or still waiting on review. Also check whether the pull request is
  already landing: in a merge queue, or set to auto-merge. Use the GitHub
  account or tool your instructions specify for that repository. See
  [Merge queue and auto-merge](#merge-queue-and-auto-merge).
- **Code:** whether a described bug or gap still exists on the default branch,
  or a later commit already fixed it.
- **People:** whether a Slack thread or email the task waits on got a reply.
- **Other tasks:** whether a dependency or duplicate on the board is already
  Done.
- **Links:** collect each task's pertinent links: its references, URLs or
  pull request numbers in its description and notes, and anything the
  investigation turned up, such as the commit that fixed it or the thread it
  waits on. Resolve bare numbers like `app#1234` to full URLs.

Note anything you couldn't check, and why, rather than guessing.

Also look for earlier triage notes (lines starting `Triage YYYY-MM-DD:`). A
task kept in Waiting through two or more earlier triages is going stale; say
so and push for a decision other than Keep, such as chasing the person it
waits on (moving it to To Do, since chasing is the user's step) or dropping
it.

### Merge queue and auto-merge

`gh pr view` doesn't report merge-queue entries, and its `autoMergeRequest`
is null for a queued pull request, so a queued pull request can look idle.
Query GraphQL instead, one alias per pull request:

```sh
gh api graphql -f query='{repository(owner:"OWNER",name:"REPO"){
  a:pullRequest(number:123){...f}}}
  fragment f on PullRequest{number isInMergeQueue mergeQueueEntry{state position}
  autoMergeRequest{enabledAt enabledBy{login}} mergeStateStatus}'
```

- **In the merge queue** (`isInMergeQueue`): the pull request is landing.
  Report its queue position and state.
- **Auto-merge enabled** (`autoMergeRequest` set): it joins the queue once
  its requirements pass. Say which requirements are still outstanding, such
  as a pending check, an out-of-date branch, or a missing required review.

## 3. Walk through the tasks one at a time

Show a running count, then one task per message:

```
### 3/10 · TASK-7 · Stop sending telemetry from local dev stacks
app · bug · in Waiting since 2026-10-20

Links: [acme/app#5678](https://github.com/acme/app/pull/5678) ·
[telemetry.py](https://github.com/acme/app/blob/main/backend/telemetry.py)

Work: Get app#5678 reviewed and merged. The fix and its tests are done;
nothing left to write.

State: Approved by Sam; one required check still failing (types gate, which
also fails on main).

Recommend: **l** — later. The next step is yours: rerun or explain the
failing check.

d done · x drop · l later · w waiting · a agent · p in progress · t talk
```

- **Links** lists the task's pertinent links as clickable markdown, with a
  short label each. Mark any you found that aren't on the task yet, such as
  with "(new)". Write "none" if there are none.
- **Work** is one or two plain sentences on what finishing the task actually
  takes, with a rough size (trivial, small, medium, large). Describe the
  remaining work, not the task's history.
- **State** is what the investigation found, with its evidence.
- **Recommend** is one choice and a one-line reason.

Then end your turn and wait. The user answers with a letter, `ok` or `y` to
accept the recommendation, or free text. Accept free text that changes the
decision's details, such as a different reason, note, or due date. If the
user says to accept the rest of the recommendations, apply them all without
asking again, but still list each one in the summary.

When the user picks **t** (talk), they want more context before reaching a
verdict. Stay on that task and discuss it. Keep investigating without
changing anything, answer their questions, and bring up whatever bears on the
decision: the full task text, the relevant code, a PR's diff or review
threads, or the Slack or email thread behind it. Keep answers focused on the
decision, not a full report. Apply nothing until the user picks an outcome.
If the discussion changes your view, say so and give a revised
recommendation, then show the choice line again.

Treat a question from the user as **t**. If you can't recommend an outcome
without the user's input, recommend **t** and say what you need to know.

If several tasks are clearly done, such as their pull requests merged, you
may present them together first and close them on one confirmation.

## 4. Apply each decision right away

Apply the decision before presenting the next task. Start every note with
`Triage YYYY-MM-DD:` using today's date.

| Choice | Meaning | Commands |
| --- | --- | --- |
| **d** done | Verified finished | `task edit N -s Done --final-summary "…"`, citing the evidence, such as the merged PR |
| **x** drop | Not worth doing | `task edit N --append-notes "Triage …: dropped — <reason>"`, then `task archive N` |
| **l** later | The next step is the user's, not now | `task edit N -s "To Do" --append-notes "Triage …: <next step and why it's the user's>"` |
| **w** waiting | The next step is someone else's | `task edit N -s Waiting --append-notes "Triage …: waiting on <who/what>"` |
| **a** agent | Delegate to an agent | See [Delegating](#5-delegating) |
| **p** in progress | Already landing | `task edit N -s "In Progress" --append-notes "Triage …: <landing state> — <what's left after it lands>"` |

- With any decision except drop, add the links the task was missing in the
  same command, titled as the task-tracking rule describes: one `--add-ref`
  per bare URL, plus a `Links:` note with a `- Title: URL` line for each, so
  the next reader has them.
- Recommend **p** when the work is already landing without more effort from
  the user: its pull request is in a merge queue, or has auto-merge enabled
  with only checks or a branch update outstanding. Record the queue position
  or the outstanding checks, and any steps the task lists for after it lands.
- If auto-merge is enabled but a required review is missing, the pull request
  can't land until someone reviews it. Recommend **w** and name the reviewer
  it's waiting on.
- Recommend **w** only when the next step belongs to someone else. Name who
  or what it's waiting on. If the user has a check-by date, add `--due-date`.
- If the next step is the user's own, such as answering review comments,
  fixing a failing check, or chasing someone who hasn't replied, recommend
  **l**, with a due date if it's urgent.
- Archiving keeps the task's record and ID, so dropping is reversible with
  `backlog task restore`.

## 5. Delegating

When the user picks **a**, write a brief that an agent with no knowledge of
this conversation can execute, and store it in the task so any agent or
session can pick it up later:

```sh
BACKLOG_CWD=~/Code/tasks backlog task edit N -s "To Do" --add-label agent \
  --plan $'…brief…' --append-notes "Triage …: delegated to an agent"
```

The brief says, briefly:

- The goal and why it matters.
- The repository and the files, pull requests, or threads to start from, as
  links.
- What you found during investigation, so the agent doesn't redo it.
- What done looks like, such as a passing test or an opened pull request.
- Limits: follow the repository's AGENTS.md and the task-tracking rule, work
  on a new branch, and don't merge or post anything that needs the user's
  approval.

If the task is ambiguous, risky, or needs a decision only the user can make,
say so and recommend something else instead.

Then launch it before presenting the next task. Delegated work runs in its
own top-level agent thread, so the user can track it alongside their other
agents. Show a direct link to the task, its folder (the repository or its
grove worktree), and its prompt. Link the task's file, the `File:` path from
`backlog task view`, as a markdown link with angle brackets around the path
because it contains spaces. Keep the link outside the code block so it stays
clickable:

````
**[TASK-7](</Users/me/Code/tasks/backlog/tasks/task-7 - Stop-sending-telemetry.md>)**: Local telemetry guard
```
Folder: ~/Code/app/main
Prompt: Do TASK-7 from ~/Code/tasks; its Implementation Plan has the brief.
```
````

- If you have a tool that creates a new agent thread, such as Zed's
  `create_thread`, start the thread in that folder with that prompt, then
  move on.
- Otherwise, show the folder and prompt, end your turn, and wait for the
  user to say they've started it before presenting the next task.

The brief tells the agent to set the task In Progress when it starts, per
the task-tracking rule.

Don't use sub-agents (such as `spawn_agent`) for delegated tasks unless the
user asks. They run nested inside the triage thread, where the user can't
track them with their other agents.

## 6. The To Do pass

After the last Waiting task, show how many tasks are in To Do and ask whether
to go through them too. If the user declines, go to the wrap-up.

```sh
BACKLOG_CWD=~/Code/tasks backlog task list -s "To Do" --json
```

Run the same steps over To Do: investigate every task, present them one at a
time with the same format and choices, and apply each decision right away.
Present high-priority and overdue tasks first, then the rest oldest first,
still deciding blockers before the tasks that depend on them.

- **l** (later) leaves the task in To Do. It's the normal outcome for work
  that's still worth doing; add a note only if the investigation found
  something worth keeping.
- Look hardest for tasks that no longer need doing: already fixed on the
  default branch, superseded, or duplicated by another task. Recommend
  **d** or **x** for those.
- Recommend **a** for self-contained tasks an agent could finish without the
  user's input.

## 7. Wrap up

Summarize the pass:

- Counts per outcome, and one line per task with its decision.
- What's left in Waiting, each with what it's waiting on.
- Each delegated task, with its link, folder, and prompt in case a thread
  didn't start or needs restarting.

If you started threads yourself, report each one's result when it finishes,
in a line or two, with links to any branches or pull requests.
