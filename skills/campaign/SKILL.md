---
name: campaign
description: Plan and steer a body of work too large for one pull request across several agents working in parallel — break it into focused stories, order them as a dependency graph on the Backlog.md board in ~/Code/tasks, mark the checkpoints where the user tests before work goes further, queue each wave for agents through /sidequest, and land and replan between waves. Use when the user runs /campaign, or asks to run several threads of work at once, to plan work for multiple agents or worktrees, or to resume or advance a campaign.
---

# Campaign

A campaign is a body of work made of many small pull requests, worked by
several agents at once and steered by the user at checkpoints. It differs from
a phased plan:

| | Phased plan | Campaign |
|---|---|---|
| Branches | One, with a commit per phase | One per story, each from the default branch |
| Pull requests | One | One per story |
| Plan lives in | `PLAN-<branch>.md` on the branch | A parent task on the board |
| Who works it | This session, start to finish | Queued agents, a wave at a time |
| User checks in | Before and after | At checkpoints between waves |

Use the board in `~/Code/tasks`. Pass `BACKLOG_CWD=~/Code/tasks` on every
`backlog` command, change tasks only through `backlog` commands, and follow
the task-tracking rule for titles, labels, projects, and links. Sync the board
with `--pull` before reading it, and without it after each batch of edits.

## Arguments

`/campaign [name | TASK-ID | description]`

- A description starts a new campaign from step 1.
- A campaign's name or parent task ID resumes it at step 6.

## Principles

- **One story, one task, one branch, one pull request.** A story is small
  enough to review in one sitting and stands on its own when merged.
- **An edge means merged.** A story depends on another only when it needs that
  work on the default branch. Never stack branches: review takes time, and
  stacked branches drift and conflict while they wait.
- **Wide and shallow.** Prefer many independent stories over long chains. When
  several stories need a shared piece, make that piece a small foundation
  story of its own (an interface, a data table, a hook) and land it first.
- **Plan one wave ahead.** Write full briefs only for the next wave. Later
  waves are a sketch, replanned after each checkpoint with what was learned.
- **Facts come from where they live.** The project's AGENTS.md says how to
  build, test, review, and open pull requests there. The machine's own agent
  instructions say how much can run at once and which shared services exist.
  Read both rather than assuming.

## 1. Discuss

Read the project's roadmap, architecture docs, recent pull requests, and open
board tasks for the area. Summarize the open threads, then settle with the
user:

- The goal of the campaign, and what is out of scope.
- Design questions only the user can answer. Ask them now; a story that needs
  one can't be queued.
- What the user wants to feel or see before work goes further. These become
  checkpoints.

## 2. Break it into stories

For each story, note:

- A short title, a branch name (flat, no slashes), and its repository.
- What it builds, and what done looks like.
- The files and areas it will likely touch.
- Its **checkpoint kind**:
  - `none`: tests and review are enough.
  - `visual`: changes what is drawn, so its pull request shows pictures, as
    the project's AGENTS.md describes.
  - `playtest`: a mechanic whose feel only the user can judge.
  - `design`: needs a decision from the user before it can be written.
- Whether it leans on a shared resource that runs one job at a time, such as
  a GPU shot queue, so a wave doesn't load it with many at once.

## 3. Draw the graph

Add two kinds of edges:

- **Needs:** the story builds on another's merged work.
- **Conflicts:** two stories would edit the same files, so running them at
  once would cost a painful merge. Predict each story's touches, then check the
  repository's history for files that usually change with them:

  ```sh
  git log --since=3.months --name-only --format= -- <predicted paths> | sort | uniq -c | sort -rn | head -20
  ```

  Where two stories overlap on a file both change heavily, either order them
  with an edge, or split the shared change into a small foundation story both
  depend on. Don't keep a fixed list of hotspot files; derive it each time.

Group the stories into **waves**: each wave is the set of stories whose edges
all point into earlier waves. End a wave at a checkpoint when the next wave's
shape depends on what the user sees.

A checkpoint is a task of its own, owned by the user: it has no queue label,
so no agent picks it up, and the next wave's stories depend on it. It holds a
**test sheet**: what to try, with clickable links into the running app (as
the project's AGENTS.md describes), what to look for in each, and the
questions to answer. The user marks it Done once satisfied, which releases the
next wave.

Check the concurrency the machine's instructions allow and the queue
watcher's limit. A wave wider than that is fine; the extra stories wait their
turn.

## 4. Write the campaign task

Create a parent task titled for the campaign, labeled with the repository's
name and `campaign`, In Progress. Its description holds:

- The goal and scope from step 1.
- The graph, as a list per wave: each story's task ID, title, kind, and what
  it needs, and each checkpoint.
- Decisions the user made, and open questions with their current answers.

Its notes are the campaign's log: append what landed, what each checkpoint
decided, and how later waves changed.

Show the user the graph and ask for approval before creating story tasks.

## 5. Queue the next wave

For each story in the wave, create a task as a subtask of the campaign
(`--parent`), labeled with its repository and with its checkpoint kind
(`visual`, `playtest`) when it has one. Then hand it off with `/sidequest`'s
steps 2–4 in `queue` mode: a self-contained brief starting with `Repo:` and
`Branch:` lines, its edges as `--dep`, and the queue label. Each brief also
says:

- The campaign it belongs to and what its neighbours build, so it stays in its
  own scope and doesn't anticipate theirs.
- Its checkpoint kind: for `visual`, the pictures its pull request must show;
  for `playtest`, the scenario or links the test sheet will use.
- To open its pull request as the repository's AGENTS.md says, such as with an
  automated-review label, and not to merge.

Create each checkpoint task in To Do without the queue label, with its test
sheet as its description, depending on the stories it tests. Make the next
wave's stories depend on it.

A `design` story isn't queued: list its question on the checkpoint, and write
its brief once the user decides.

## 6. Steer between waves

Resuming a campaign starts here. Read the campaign task and its subtasks, then:

- **Running:** report each story's column, its pull request, and its review
  state. Stories in Waiting are in review.
- **Failed:** a story whose agent run failed is back in To Do with a failure
  label. Read its notes, then rewrite its brief, split it, or take it over, as
  the user prefers.
- **Ready to land:** when a wave's pull requests have passed review, land them
  together with `/land-prs`, which sets each story's task Done on merge. Land
  in the graph's order, so later merges take earlier ones in.
- **At a checkpoint:** once its stories have landed, tell the user it's ready,
  with its test sheet. Record their feedback in the campaign task's notes,
  turn fixes into new stories, replan the next wave from what was learned, and
  return to step 5.

Never mark a checkpoint Done for the user, and never merge without their say
where the project requires it.

## 7. Finish

When the last wave has landed and its checkpoint has passed:

- Make sure the project's docs describe what the campaign built, and move what
  is left to its roadmap or to new To Do tasks.
- Set the campaign task Done, with a one- or two-sentence summary.
- Report what landed, as links to its pull requests, and what was left for
  later.
