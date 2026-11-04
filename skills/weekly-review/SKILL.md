---
name: weekly-review
description: Run a weekly retrospective of the user's work from their Backlog.md board in ~/Code/tasks, their agent session history, their pull requests, and any chat, calendar, ticket, or planning servers they have — what got done, what moved fast or stalled, whether it matched priorities, and what slowed it down — then recommend rule and skill changes, habits, and bigger shifts for next week, and save the review on the board. Use when the user runs /weekly-review or asks for a weekly review, a retrospective, or how their week went.
---

# Weekly Review

Look back over a week of work to make the next one better. A standup lists
what happened; this review asks why. What went well, what stalled, whether
time went where the priorities said it should, and what in the user's habits
or tooling would change that. Each review checks the last one's
recommendations, so improvements compound week over week.

Investigate and write. Don't change tasks, pull requests, or messages while
gathering. The only changes are saving the review as a board doc and, after
the user picks recommendations, creating tasks or handing them to
`/sidequest`.

Use the board in `~/Code/tasks`. Pass `BACKLOG_CWD=~/Code/tasks` on every
`backlog` command, and change the board only through `backlog` commands.
Run `BACKLOG_CWD=~/Code/tasks ~/.agents/bin/backlog-md-sync --pull` first.

## 1. Pick the period and read the last review

Default to the current calendar week: Monday at 00:00 in the user's local
timezone until now. If today is Monday, review the previous week instead.
Use the period the user names, if any. Call the start date `SINCE`, as
`YYYY-MM-DD`.

Read the most recent earlier review:

```sh
BACKLOG_CWD=~/Code/tasks backlog doc list --plain
BACKLOG_CWD=~/Code/tasks backlog doc view doc-N --plain
```

Reviews are docs titled `Weekly review YYYY-MM-DD`. The last one's **Next
week** focus and **Decisions** are this week's baseline: for each, find out
whether it happened and whether it helped. If there's no earlier review, say
this is the first and skip the comparison.

## 2. Gather

Collect evidence from every source below before judging anything. The
sources are independent, so gather them in parallel, with sub-agents for the
larger ones when available. Ask each for facts with links, not conclusions.

### The board

```sh
export BACKLOG_CWD=~/Code/tasks
backlog task list -s Done --json            # also "In Progress", Waiting, "To Do"
backlog task view TASK-N --plain
git -C ~/Code/tasks log --since=SINCE --reverse --format='%ad %s' --date=format:'%a %H:%M'
```

- **Done:** tasks completed in the period, with their final summaries.
  `/backlog-triage` archives Done tasks from before the current week, so for
  a past week also read `~/Code/tasks/backlog/archive/tasks/`.
- **Open:** every In Progress and Waiting task, with how long it's been in
  that column and who or what it waits on. High-priority and overdue To Do
  tasks.
- **History:** the board's git log records each change. In synced mode,
  each commit names its transition, such as `TASK-6 Fix-login: To Do → In
  Progress`. From it, work out each finished task's time from creation or
  In Progress to Done, tasks that sat in one column all week, tasks that
  bounced between columns, and tasks created mid-week, which show unplanned
  work. Without synced mode, the nightly commits show at least which days
  each task changed.
- **Where time went:** group tasks by label or project.

### Agent sessions

```sh
~/.agents/bin/backlog-agent-sessions --since SINCE
~/.agents/bin/backlog-agent-sessions prompts SESSION-ID [--chars N]
```

The first lists every Copilot CLI, Claude Code, and Zed session active in the
period: its client app, time span, number of prompts, folder, and the tasks
it named or touched. The second prints one session's prompts in order.

- Tally sessions and prompts by project and by client. Prompts in the
  period are a rough measure of the user's attention, though short replies
  such as "yes" or a one-letter triage choice count the same as a long
  brief. A session's time span isn't a measure, since sessions sit open for
  days.
- Attribute sessions by folder, but for a general-purpose folder, such as a
  notes folder where the user runs triage and standups, use the tasks
  column and the prompts instead.
- Sessions from a non-interactive client, such as a nightly job's `cli`
  session in the board's folder, are automations. Count them apart.
- Read the prompts of the sessions with the most prompts, and of any task
  that took several sessions. Look for:
  - **Corrections**, such as "no", "that's wrong", or "still broken", and
    what the agent got wrong.
  - **Repeated instructions** the user typed in more than one session.
    These are candidate rules.
  - **Repeated workflows**, the same multi-step request run by hand more
    than once. These are candidate skills.
  - **Tooling friction**: sign-in failures, slow or hung commands, sandbox
    blocks, approval prompts, lost context, or restarting a session to
    continue.
- When there are more than about ten such sessions, split them across
  sub-agents, giving each this list and asking for quoted evidence with
  session IDs.

### Pull requests and code review

Search each code host, account, and organization the user's instructions
name, using any account wrapper they require. Include pull requests the user
opened, and ones they reviewed, updated in the period. For each, note the
time to first review and to merge, and any still open without a review.
Long waits on reviewers are a social bottleneck; long waits on failing
checks are a technical one.

### Chat, calendar, tickets, and planning

Use whatever servers the user's instructions list, read-only, and follow
their rules on what needs asking first, such as searching private channels.

- **Chat:** questions the user asked others and how long replies took;
  threads still unanswered; requests that interrupted planned work.
- **Calendar:** hours in meetings per day, and the longest free block each
  day.
- **Tickets and planning tools:** the official priorities and status for
  the user's projects, to compare against what got done.

If a server fails to sign in, note it and carry on without it.

### Notes and rules

- Dated notes the user keeps, such as standup notes, for what they planned
  each day.
- The user's installed rules and skills, so recommendations build on what
  exists instead of repeating it.

## 3. Assess

Answer each question with evidence. Say where each fact came from and
whether it was measured or inferred. Be candid but not harsh: the point is
to find what to change, not to grade the user.

- **What got done?** Group by theme. Separate what shipped from what was
  only started.
- **Did it follow priorities?** Judge the week against the user's own
  priority order, if their instructions state one, rather than a default
  that ranks board tasks above everything else. For example, someone may
  rank on-call, unblocking teammates, or fixing their workflow when it gets
  in the way above high-priority tasks; time spent on those is then the
  plan working, not a distraction. Estimate how much of the week went to
  each priority, and compare what got done with the high-priority tasks,
  the last review's focus, daily plans, and the planning tools. Flag work
  that ran ahead of a higher priority, such as tooling no problem called for
  while a teammate waited on a review.
- **What moved fast, and why?** Find what the quick items had in common,
  such as a clear scope, a skill that covered the workflow, or a responsive
  reviewer.
- **What got stuck, and why?** For each stalled item, name the bottleneck
  and its kind. Before calling it an attention problem, check whether
  higher priorities in the user's order took the time.
  - *Technical:* builds, flaky tests, broken tools, access, slow systems.
  - *Social:* review latency, unanswered questions, unclear ownership,
    decisions waiting on someone.
  - *Attention:* too many threads at once. Count tasks In Progress at the
    same time, and projects touched per day.
  - *Scope:* vague tasks, or tasks that grew.
- **How well did agents work?** Where they saved time, and where the user
  had to correct, repeat, or babysit them.

## 4. Recommend

Rank by expected payoff, and keep each tier to about three items so the list
gets acted on. Tie each one to the evidence behind it.

- **Tooling:** concrete changes to rules, skills, scripts, or config. Name
  the file, the change, and the problem it prevents, such as "add a rule to
  run the targeted tests first: three sessions reran the full suite after a
  one-file change". Prefer changing an existing rule or skill to adding a
  new one. Write each so it could become a `/sidequest` brief.
- **Habits:** specific behaviors for the user, such as "block 9–11 each
  morning for the migration: it never got an hour at a stretch", or "ask
  the data team on day one: both questions to them waited three days".
- **Big picture:** at most two shifts worth considering, and only when the
  evidence points there, such as the editor or agent client, how sessions
  are orchestrated, or where information lives. Frame each as an experiment
  for next week, with how to tell whether it worked.
- **Next week:** three to five focus items, in priority order.

## 5. Save the review

Save the review as a board doc, so it syncs with the board and the next
review can find it. Date it by the period's last day.

```sh
export BACKLOG_CWD=~/Code/tasks
backlog doc create "Weekly review YYYY-MM-DD" -p weekly-reviews -t other --plain
backlog doc update doc-N --content "$(cat "$REVIEW_FILE")"
~/.agents/bin/backlog-md-sync
```

`create` prints the doc's ID and path. Write the draft to a temporary file
outside any repository, and delete it afterward. If a review for this period
already exists, the user may have edited it: show what you'd change and ask
before replacing it.

Shape it like this:

```markdown
**Period:** Mon Nov 2 – Fri Nov 6

## Summary
<two or three sentences: the shape of the week, and the one thing to change>

## Last week's experiments
- <recommendation> — <followed or not>; <whether it helped, with evidence>

## Done
- <theme>: <one line per item, with links>

## Moved fast
## Got stuck
- <item> — <bottleneck> (<kind>): <evidence>

## Priorities vs. actual
<share of the week per priority, in the user's order; what slipped, and whether a higher priority or something else displaced it>

## Recommendations
### Tooling
### Habits
### Big picture

## Next week
1. <focus item>

## Decisions
<filled in after the discussion>
```

Link every pull request, thread, and doc the review cites, following the
user's link rules. Refer to tasks by ID and title.

## 6. Discuss and act

Reply with a link to the doc's file, the summary, and the recommendations,
numbered so the user can pick. Note any source you couldn't read. Then ask
which to act on:

- **Tooling changes:** hand each picked change to `/sidequest`, one task
  per change, with the evidence in its brief.
- **Habits and experiments:** offer a To Do task for any that needs one,
  such as a reminder or a conversation to have.
- **Declined items:** record them too, with the reason, so the next review
  doesn't propose them again.

Record the decisions in the doc's **Decisions** section, then sync the
board.
