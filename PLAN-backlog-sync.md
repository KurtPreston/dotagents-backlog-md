# Plan: backlog-sync

## Goal

Add an optional **synced mode** that keeps one task board in step across several personal machines through a private git remote, typically on a self-hosted git server. Today the board is local only, and a nightly job commits the day's changes with a Copilot-written summary. In synced mode, each change gets its own commit with a plain message, pushed promptly, so two machines rarely diverge far enough to conflict. When they do, the plugin resolves the conflict itself.

Synced mode is off by default. With it off, everything behaves as it does today.

## Scope

In:

- A git-ignored `config.jsonc` at the plugin root, with a committed `config.example.jsonc`, holding `sync.enabled` and the remote URL. The remote's URL never appears in committed files.
- A `backlog-md-sync` script that commits local changes with a plain message, fetches, rebases, and pushes. It tolerates an unreachable remote, and offers `setup` to connect a board to the remote.
- Automatic conflict resolution: renumbering duplicate task IDs created offline on two machines, and asking Copilot CLI to merge edits to the same task file, falling back to a clear message when neither works.
- Scheduling: in synced mode, the launchd job runs `backlog-md-sync` every 15 minutes and at login instead of the nightly commit.
- Rule and skill updates: agents sync at session start, before creating a task, and after changing tasks, and they keep task titles short, since titles are what make commit messages readable.
- Tests for the sync script against a local bare repository standing in for the remote.

Out:

- Slugs, UUIDs, or other non-numeric task IDs. Backlog.md 1.55.3 supports only prefix-plus-number IDs and drops unknown frontmatter keys on edit. Titles serve as the readable name instead, through the task filename.
- Merging two boards that already have separate histories. `setup` refuses that case and explains it.
- Sharing with other people, and work machines.
- Backlog.md's own `auto_commit`, which stays off. The plugin owns commits so it can write consistent messages and push.

## Execution rules

- All work happens on the `backlog-sync` branch of this plugin repository. One plan, one branch, one commit per phase.
- Prefix every commit message with `backlog-sync: `.
- For each phase: implement only its scope, run validation, fix failures, commit.
- Work around small obstacles and log them under Obstacles. Stop only if a fundamental assumption is wrong or a finding reshapes the effort.
- Log existing bugs found along the way under Found bugs. Fold in fixes that belong to this effort, save small unrelated fixes for their own branches, and leave nuanced ones unfixed for discussion.
- This repository is public. Refer to the remote generically, such as "a private git remote" or "a self-hosted git server", and never commit its hostname or URL.
- After the last phase: update docs and commit, delete this file and commit, open a pull request (draft, after asking first, since the repository is public), fix each small unrelated bug on its own branch from the base branch with its own pull request, then report results with every obstacle and workaround, every bug found and how it was handled, and how the user can try the changes.

## Validation

This plugin has no package manifest or test runner, so validation is:

- `bash -n` on every script, plus `shellcheck scripts/* tests/*` when shellcheck is installed.
- `tests/run-sync-tests`, added in phase 2. It builds a temporary bare repository and two board clones standing in for two machines, and runs each scenario against them. It prints one line per scenario as it runs and finishes in well under a minute.
- From the dotagents checkout, `./install.sh` succeeds and links any new scripts into `~/.agents/bin`.

## User steps

After the pull request merges, or earlier to try the branch:

1. Create an empty private repository on the git server, such as `tasks`, and make sure each machine's SSH key can push to it.
2. On the machine whose board is the source of truth, which is this one:

   ```sh
   cd ~/Code/dotagents/plugins/dotagents-backlog-md
   cp config.example.jsonc config.jsonc   # then set sync.enabled to true and sync.remote to the repository's SSH URL
   cd ~/Code/dotagents && ./install.sh
   ~/.agents/bin/backlog-md-sync setup    # adds the remote, enables remote_operations, and pushes the history
   ~/.agents/bin/backlog-md-schedule install
   ```

3. On each other machine, after installing dotagents and this plugin and writing the same `config.jsonc`:

   ```sh
   ~/.agents/bin/backlog-md-sync setup    # clones the board into BACKLOG_CWD when it doesn't exist yet
   ~/.agents/bin/backlog-md-schedule install
   ```

## Phases

### Phase 1: Sync configuration

- Add `config.example.jsonc` documenting `sync.enabled` (default `false`), `sync.remote` (the remote URL), and `sync.branch` (default `main`), and add `config.jsonc` to a new `.gitignore`.
- Add `lib/config.mjs`, a dependency-free Node script that reads `config.jsonc`, strips comments and trailing commas without touching `//` inside strings such as URLs, and prints the requested values in a shell-friendly form. Keep it in `lib/`, not `scripts/`, so the installer doesn't link it into `~/.agents/bin`.
- Add `lib/common.sh` for what the scripts share: the PATH setup for launchd, resolving the plugin folder through the `~/.agents/bin` symlink, finding `BACKLOG_CWD` as `backlog-md-commit` does now, and loading the sync config. Move `backlog-md-commit`'s copies of these into it.
- Done when a missing config reads as sync disabled, and a config with comments, trailing commas, and a URL reads correctly.

### Phase 2: Commit, fetch, rebase, and push

- Add `scripts/backlog-md-sync`:
  - With sync disabled, it exits 0 silently, so agents can call it unconditionally.
  - It takes a lock (an atomic `mkdir`) so an agent and the scheduled job can't run it at the same time. A stale lock older than 10 minutes is cleared.
  - It commits any changes with a plain message built from the staged diff. For one task, the subject is `TASK-6 Backlog.md-synchronization: To Do → In Progress` for a status change, `…: created` for a new file, `…: archived` or `…: deleted` for a move or removal, and `…: updated` otherwise. The ID and title come from the filename. For several tasks, the subject is `Update N tasks` with one such line per task in the body. Changes outside task files, such as `config.yml`, are summarized by path.
  - It fetches with a short connection timeout. If the remote is unreachable, it logs one line, keeps the local commits, and exits 0, since the next run will push them.
  - It rebases onto the remote branch and pushes. If the push is rejected because another machine pushed first, it fetches and rebases once more before giving up until the next run.
  - `--pull` fetches and rebases without pushing, so a task can be created on top of the latest board.
- Add `backlog-md-sync setup`. When `BACKLOG_CWD` doesn't exist, it clones the remote there. When the board exists with no remote, it adds `origin` and pushes, but only if the remote is empty, and otherwise it refuses and explains that merging separate histories is unsupported. When the remote is already set, it checks that it matches the config. In every case it sets `remote_operations: true` in the board's `backlog/config.yml` through `backlog config set`, so new IDs account for tasks already pushed by other machines.
- Add `tests/run-sync-tests`, covering: sync disabled is a no-op; a status change produces the expected subject and reaches the remote; a multi-task change produces the expected body; an unreachable remote exits 0 and keeps the commit; edits to different tasks on two clones both reach the remote; and `setup` in both its clone and push forms.

### Phase 3: Automatic conflict resolution

- **Duplicate IDs.** Two machines that create tasks while offline can both make `TASK-N`. The rebase succeeds, since the filenames differ, but leaves two files with the same ID. After each rebase, the script finds duplicate IDs, keeps the one already on the remote, and moves the local one to the next free ID. It renames the file, rewrites its `id:`, and updates `dependencies` and `parent_task_id` entries that pointed at the old ID in tasks created only on this machine. It commits the change as `TASK-N → TASK-M: renumbered after sync`. Backlog.md has no renumber command, so this is the one place the plugin edits task files directly. Afterward, `backlog task view` must still parse both tasks.
- **Same-file edits.** When the rebase stops on a conflict in a task file, the script gives Copilot CLI the file with its conflict markers and the instructions in a new `prompts/resolve-conflict.md`, with tools for the shell, file writes, and URLs denied, as in `backlog-md-commit`. It takes the merged file from Copilot's output, refusing output that still has conflict markers or no longer parses as a task. The instructions favor keeping both sides' notes, and the later `updated_date`. It then continues the rebase.
- **Fallback.** If Copilot fails or anything else conflicts, the script aborts the rebase, so the board still shows the local version, logs which files conflicted, and exits non-zero with a message telling the agent or user to run `git -C "$BACKLOG_CWD" pull --rebase` and resolve by hand. The scheduled job retries on its next run.
- Extend `tests/run-sync-tests` with: a duplicate ID created on two clones; the same task edited on two clones, using a stub `copilot` on `PATH` so the test is deterministic; and a stub that fails, to check the fallback.

### Phase 4: Scheduling

- Add `launchd/backlog-md-sync.plist`, which runs `backlog-md-sync` every 15 minutes and at login, logging to `~/Library/Logs/backlog-md-sync.log`. The 15-minute run catches edits made outside agents, such as in `backlog browser`, and keeps an idle machine current.
- Have `backlog-md-schedule install` pick the job by mode: the sync job when sync is enabled, the nightly commit job otherwise, unloading and removing the other. Have `status`, `run`, and `uninstall` act on whichever is installed.
- Have `backlog-md-commit` exit with a message, without committing, when sync is enabled, so a stale nightly job can't make a summary commit that skips the push.

### Phase 5: Agent rules and skills

- Update `rules/task-tracking.md`:
  - Replace "Don't commit in `~/Code/tasks`" with: run `~/.agents/bin/backlog-md-sync` after changing tasks, and `~/.agents/bin/backlog-md-sync --pull` once at the start of a session before first reading the board, and again before creating a task. The script is a no-op when sync is off, so the rule doesn't depend on the mode. Still never `git commit` in the board by hand.
  - Ask for short titles of about six words or fewer that name the work, since the title becomes the filename and the commit message.
  - Say what to do when sync reports a conflict it couldn't resolve.
- Update `skills/task/SKILL.md` and `skills/backlog-triage/SKILL.md` to pull before reading the board and sync after their changes.
- Rerun dotagents' `./install.sh` and check that the generated `AGENTS.md` picks up the new rule text. It's git-ignored, so this is local only.

## Obstacles

## Found bugs
