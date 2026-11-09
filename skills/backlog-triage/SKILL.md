---
name: backlog-triage
description: Archive Done tasks from before this week, surface failed, running, and queued agent work, raise high-priority tasks untouched for 3+ days, then walk the user through every Waiting task on their Backlog.md board in ~/Code/tasks and optionally their non-queued To Do tasks, one at a time, deciding each one's fate. Use when the user runs /backlog-triage or asks to triage, review, or clean up their board or what they're waiting on.
---

# Backlog Triage

Waiting holds tasks whose next step belongs to someone else: pull requests in
review, questions out to other people, work blocked on another task. Left
alone, it fills with things that already came back or quietly stalled. This
skill first archives older completions to keep Done focused on this week,
then surfaces agent failures and queue status, raises high-priority work that
hasn't moved in days, gives every Waiting task a decision, and offers the
same pass over To Do tasks that aren't already delegated.

Your job is to investigate and recommend, not to do the work. Don't fix,
merge, or post anything during triage. The only work that starts is what the
user delegates, and it starts as soon as they delegate it.

Use the board in `~/Code/tasks`. Pass `BACKLOG_CWD=~/Code/tasks` on every
`backlog` command, and change tasks only through `backlog` commands. Run
`BACKLOG_CWD=~/Code/tasks ~/.agents/bin/backlog-md-sync --pull` before
loading the board, and `BACKLOG_CWD=~/Code/tasks ~/.agents/bin/backlog-md-sync`
after applying each decision, as the task-tracking rule's Syncing section
describes.

## 0. Archive older Done tasks

After syncing, clean up Done automatically, without asking for each task.
This is a standing preference: Done shows this week's completions, while
older work stays searchable in the archive.

```sh
BACKLOG_CWD=~/Code/tasks backlog task list -s Done --json
```

- Set the cutoff to Monday at 00:00 in the user's local timezone, using the
  current date. Compare timezone-aware timestamps; this is a calendar week,
  not a rolling seven days or Monday midnight UTC.
- Archive only tasks currently in Done whose latest completion was strictly
  before the cutoff. Keep completions at or after the cutoff, even if the
  task was created weeks ago. Never age out To Do, In Progress, or Waiting.
- Prefer a completion timestamp if available. The current CLI lists
  `updatedAt` and `createdAt`, not a completion date: an `updatedAt` before
  the cutoff establishes that a Done task was already complete. For a
  recent update, inspect the task's notes and latest transition into Done
  in the board's git history to distinguish completion from later edits.
  Use the task timestamp recorded at that transition, not the commit time:
  the nightly commit can record an earlier day's work.
- If `updatedAt` is absent, use `createdAt` only when the record and history
  show the task was created as Done. If completion timing remains missing
  or ambiguous, retain the task and report it rather than guessing.
- Recheck candidates before archiving so a reopened or newly completed task
  is not removed. Do not edit notes first, which would change `updatedAt`.

For each eligible task, then once for the completed batch:

```sh
BACKLOG_CWD=~/Code/tasks backlog task archive TASK-N
BACKLOG_CWD=~/Code/tasks ~/.agents/bin/backlog-md-sync
```

Use `task archive`, not deletion or the interactive, age-based `cleanup`
command. Records, IDs, and links are retained and `backlog task restore`
can bring a task back. Reload Done to verify the result, and report the
cutoff, archived count, and any uncertain tasks kept.

If the user requested only cleanup, stop here; otherwise continue with
agent queue status even when there were no older Done tasks.

## 0a. Surface agent queue status

Before stale-priority or Waiting decisions, read the queue configuration and
the board, even if this machine's delegation mode isn't `queue`:

```sh
~/.agents/bin/backlog-sidequest mode
BACKLOG_CWD=~/Code/tasks backlog task list --plain
BACKLOG_CWD=~/Code/tasks backlog task view TASK-N --plain
```

Use the printed `label` as the queue label (default `agent`), not a
hard-coded value. `agent-failed` is the failure marker. If the helper fails,
report the error and don't guess the label or change queue membership.
View relevant tasks in full to read assignees, dependencies, and notes.
Report these groups in order, saying when a group is empty:

1. **Failed — the user's move.** Open tasks labeled `agent-failed` come
   first, even if they also have the queue label. Show each task's link,
   title, current status, and last implementation note, including where the
   agent stopped and any decision it needs. If the last note isn't the
   failure explanation, also show the latest failure note; if none exists,
   say the reason wasn't recorded. Investigate before recommending a
   decision. Ask one task at a time: **r** retry, **o** take over, or **x**
   drop. Discuss questions without changing the task.
2. **Running.** List each In Progress task assigned to `@docent-workspace`,
   regardless of its labels, unless already handled as failed. Use one
   line per task: link, title, time In Progress, and **possibly stuck** if
   strictly more than 24 hours. Determine the start from the latest
   transition into In Progress in the board's git history or a matching
   claim note, not `updatedAt`, which later edits can refresh. Compare
   timezone-aware timestamps to now. If the start is uncertain, say
   "duration unknown"; don't invent an age or conclude the agent is dead.
3. **Queued.** List each To Do task with the configured queue label, excluding
   failures and tasks still assigned to `@docent-workspace`. Use one line
   per task: link, title, and either "ready for pickup" or "blocked by"
   links to every unfinished dependency with its status. Check dependency
   tasks; only Done satisfies a dependency. Missing or unreadable
   dependencies mean readiness is unknown, not ready. Include blocked
   queued work, not just tasks the watcher can start now.

A To Do task still assigned to `@docent-workspace`, or a claimed task in
another unexpected status, is inconsistent: report its status and assignee
separately instead of calling it queued or running. Don't clear a live claim
or requeue work automatically. Done and Waiting tasks aren't queued just
because they retain the label; Waiting results still get the normal pass.

For a failed task, re-read it before applying the user's decision. If it has
been claimed or changed since presentation, refresh its state before acting.
The examples use `$QUEUE_LABEL` for the label returned by the helper:

| Choice | Commands |
| --- | --- |
| **r** retry | `task edit N -s "To Do" -a "" --remove-label agent-failed --add-label "$QUEUE_LABEL" --append-notes "Triage …: retry queued — <reason>"` |
| **o** take over | `task edit N -s "To Do" -a "" --remove-label agent-failed --remove-label "$QUEUE_LABEL" --append-notes "Triage …: user taking over — <next step>"` |
| **x** drop | `task edit N -a "" --remove-label agent-failed --remove-label "$QUEUE_LABEL" --append-notes "Triage …: dropped — <reason>"`, then `task archive N` |

Prefix each command with `BACKLOG_CWD=~/Code/tasks backlog`, use `--plain`,
and sync after each decision. Before retrying, keep or update the
Implementation Plan with what the failure taught us; preserve dependencies
so blocked retries still wait. Retry queues for the watcher even when this
machine normally launches or hands off. Never retry without the user's
decision.

Skip tasks decided here, queued tasks (including blocked ones), and claimed
tasks in the stale-priority and ordinary To Do passes. They already have a
next actor; don't offer to delegate them again. Refresh queue membership
before later passes, including tasks delegated during this triage.

## 1. Raise stale high-priority tasks

High-priority work can go untouched for days while triage covers Waiting
and the day fills with smaller things. After queue status, raise eligible
tasks so each one gets a deliberate decision.

```sh
BACKLOG_CWD=~/Code/tasks backlog task list -s "To Do" --json
BACKLOG_CWD=~/Code/tasks backlog task list -s "In Progress" --json
git -C ~/Code/tasks log --since="3 days ago" --format='%ad %s' --date=short -- backlog/tasks
~/.agents/bin/backlog-task-sessions TASK-N --days 3
```

A task is stale when its priority is `high`, it's in To Do or In Progress,
and nothing has moved it in the last 3 days. Triage, standup, and weekly
reviews write notes on many tasks and mention their IDs in many sessions, so
`updatedAt`, a bare `updated` commit, or a session that only mentions the ID
isn't evidence. Count a task as moved only if, in the last 3 days, it has:

- a status change in the board's git log, such as `TASK-6 Fix-login: To Do
  → In Progress`;
- a note or final summary about progress, other than ones starting
  `Triage`, or from a standup or review;
- commits on its pull request or branch; or
- a session in a repository folder, not the board or a notes folder, whose
  prompts worked on it. Confirm with
  `~/.agents/bin/backlog-agent-sessions prompts SESSION-ID`.

Waiting tasks are left to the Waiting pass, since their next step isn't the
user's. If none are stale, say so in one line and continue.

Investigate each stale task as in [Investigate before
asking](#3-investigate-before-asking), then present it in the same format
as the Waiting pass, adding how many days it's been untouched and why it's
stuck if the evidence shows it, such as a draft pull request with a failing
check. Ask the question directly: work it today, delegate it, or lower its
priority?

```
n now · a agent · v lower priority · l later · d done · x drop · t talk
```

| Choice | Meaning | Commands |
| --- | --- | --- |
| **n** now | The user works it today | `task edit N --due-date TODAY --append-notes "Triage …: working today — <first step>"` |
| **v** lower priority | It isn't really high priority | `task edit N --priority medium --append-notes "Triage …: lowered — <reason>"` |
| **l** later | Still high priority, but blocked until a concrete revisit date | `task edit N --due-date YYYY-MM-DD --append-notes "Triage …: stale, kept — <blocker>; revisit YYYY-MM-DD"` |

For **l**, ask for a revisit date before applying the decision. Suggest the
earliest of the blocker's expected end (if known), a date at most a week
from today, or a few days before any hard deadline. Record the agreed date
in both `--due-date` and the note; an open-ended condition isn't enough.
If the due date held a hard deadline, preserve that deadline in the note.

If a stale task's most recent `stale, kept` note has a revisit date that
has passed, say how many times earlier triages kept it. Suggest the smallest
concrete next step doable in under 30 minutes, often a message to send,
or delegating with **a**, rather than simply parking it again.

**a**, **d**, **x**, and **t** work as in the Waiting pass. Recommend **n**
for the one or two most important tasks, not all of them, since a day only
holds so much. Recommend **v** when nothing depends on the task soon, and
**a** when an agent could take the next step alone. A task kept stale
through two or more earlier triages should get a decision other than **l**.

Tasks decided here are skipped in the To Do pass.

## 2. Load the Waiting column

```sh
BACKLOG_CWD=~/Code/tasks backlog task list -s Waiting --json
BACKLOG_CWD=~/Code/tasks backlog task view TASK-N --plain
```

View every task in full. If the column is empty, say so and go to
[the To Do pass](#7-the-to-do-pass).

Order them oldest first (lowest ID), except that a task comes before any
task in the pass that depends on it, so blockers are decided first.

## 3. Investigate before asking

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

## 4. Walk through the tasks one at a time

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

## 5. Apply each decision right away

Apply the decision before presenting the next task. Start every note with
`Triage YYYY-MM-DD:` using today's date.

| Choice | Meaning | Commands |
| --- | --- | --- |
| **d** done | Verified finished | `task edit N -s Done --final-summary "…"`, citing the evidence, such as the merged PR |
| **x** drop | Not worth doing | `task edit N --append-notes "Triage …: dropped — <reason>"`, then `task archive N` |
| **l** later | The next step is the user's, not now | `task edit N -s "To Do" --append-notes "Triage …: <next step and why it's the user's>"` |
| **w** waiting | The next step is someone else's | `task edit N -s Waiting --append-notes "Triage …: waiting on <who/what>"` |
| **a** agent | Delegate to an agent | See [Delegating](#6-delegating) |
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

## 6. Delegating

When the user picks **a**, follow the `sidequest` skill's steps 2 to 5 for
this task: write its brief, then queue, launch, or hand it off as this
machine's mode says, and sync. Use what you found during investigation in the
brief, so the agent doesn't redo it, and append
`Triage …: delegated to an agent` to the task's notes.

If the task is ambiguous, risky, or needs a decision only the user can make,
say so and recommend something else instead.

Show the one-line report, then move on to the next task.

## 7. The To Do pass

After the last Waiting task, refresh queue membership and show how many
ordinary To Do tasks remain, separately from queued or claimed tasks and
tasks already decided. Ask whether to go through the remaining tasks too.
If the user declines, go to the wrap-up.

```sh
BACKLOG_CWD=~/Code/tasks backlog task list -s "To Do" --json
```

Run the same steps over eligible To Do tasks: investigate each, present them
one at a time with the same format and choices, and apply each decision right
away. Don't walk queued tasks individually; their one-line queue entries
already cover them, including those blocked on unfinished dependencies.
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

## 8. Wrap up

Summarize the pass:

- Older Done tasks archived, this week's cutoff, and any uncertain dates kept.
- Agent failures and their decisions, running tasks and any possibly stuck
  claims, and queued tasks with their dependency blockers.
- Each stale high-priority task and its decision, with the ones to work today
  first.
- Counts per outcome, and one line per task with its decision.
- What's left in Waiting, each with what it's waiting on.
- Each delegated task, with its link, folder, and prompt in case a thread
  didn't start or needs restarting.

If you started threads yourself, report each one's result when it finishes,
in a line or two, with links to any branches or pull requests.
