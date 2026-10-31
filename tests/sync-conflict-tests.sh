# Conflict scenarios for tests/run-sync-tests, sourced after its scenarios run, using its boards and helpers.
# Board a and b are both in sync with the remote when this starts.

# Put a stub `copilot` on PATH that keeps this machine's side of each conflict, or fails when asked
stub_dir="$work/stub"
mkdir -p "$stub_dir"
cat >"$stub_dir/copilot" <<'STUB'
#!/usr/bin/env bash
# Test stub for Copilot CLI: prints the conflicted file from the prompt with this machine's side kept.
[[ -z "${STUB_COPILOT_FAIL:-}" ]] || exit 1
while [[ $# -gt 0 && "$1" != -p ]]; do shift; done
printf '%s\n' "$2" |
  awk 'found { print } /^Conflicted file/ { found = 1; getline; next }' |
  awk '/^<<<<<<< / { skip = 1; next } /^=======$/ { skip = 0; next } /^>>>>>>> / { next } !skip'
STUB
chmod +x "$stub_dir/copilot"
export PATH="$stub_dir:$PATH"

# Both machines create the next ID while apart; the second to sync renumbers its copy and its dependents
test_duplicate_ids() {
  bl "$a" task create "From machine a"
  bl "$b" task create "From machine b"
  bl "$b" task create "Depends on b" --dep TASK-3
  sync_in "$a" >/dev/null && sync_in "$b" >/dev/null &&
    [[ "$(remote_subject)" == "TASK-3 → TASK-5: renumbered after sync" ]] &&
    ls "$b/backlog/tasks/" | grep -q '^task-5 - From-machine-b.md$' &&
    ls "$b/backlog/tasks/" | grep -q '^task-3 - From-machine-a.md$' &&
    grep -q "TASK-5" "$b/backlog/tasks/task-4 - Depends-on-b.md" &&
    BACKLOG_CWD="$b" backlog task view TASK-5 --plain | grep -q "From machine b" &&
    sync_in "$a" >/dev/null && [[ "$(git -C "$a" rev-parse HEAD)" == "$(git -C "$b" rev-parse HEAD)" ]]
}

# Both machines change one task's status; Copilot merges, and this machine's side wins in the stub
test_merge_same_task() {
  bl "$a" task edit TASK-2 -s Done
  bl "$b" task edit TASK-2 -s "To Do"
  local out
  sync_in "$a" >/dev/null && out="$(sync_in "$b")" &&
    [[ "$out" == *"merged conflicting edits"* ]] &&
    [[ ! -d "$b/.git/rebase-merge" ]] &&
    ! grep -rqE '^(<<<<<<<|>>>>>>>)' "$b/backlog/tasks" &&
    BACKLOG_CWD="$b" backlog task view TASK-2 --plain | grep -q "To Do" &&
    [[ "$(git -C "$b" rev-parse HEAD)" == "$(git --git-dir="$remote" rev-parse main)" ]]
}

# When Copilot fails, the rebase is aborted and the local commit waits for a person
test_merge_fallback() {
  sync_in "$a" >/dev/null
  bl "$a" task edit TASK-2 -s "In Progress"
  bl "$b" task edit TASK-2 -s Done
  local err status=0
  sync_in "$a" >/dev/null
  err="$(STUB_COPILOT_FAIL=1 sync_in "$b" 2>&1 >/dev/null)" || status=$?
  [[ "$status" -ne 0 && "$err" == *"resolve by hand"* ]] &&
    [[ ! -d "$b/.git/rebase-merge" && -z "$(git -C "$b" status --porcelain)" ]] &&
    [[ "$(git -C "$b" log -1 --format=%s)" == "TASK-2 Second-task: To Do → Done" ]]
}

for scenario in duplicate_ids merge_same_task merge_fallback; do
  check "$scenario" "test_$scenario"
done
