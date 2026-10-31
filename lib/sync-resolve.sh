# Conflict handling for backlog-md-sync, sourced by it. Phase 3 fills these in.

# Abort a stopped rebase so the board shows the local version, and report it
resolve_rebase_conflicts() {
  local files
  files="$(git -c core.quotepath=false diff --name-only --diff-filter=U | sed 's/^/  /')"
  git rebase --abort
  echo "backlog-md-sync: rebase onto $remote_ref conflicted; resolve by hand with: git -C \"$tasks_dir\" pull --rebase" >&2
  [[ -z "$files" ]] || printf '%s\n' "$files" >&2
  return 1
}

# Give tasks that share an ID with a remote task the next free ID
renumber_duplicate_ids() {
  return 0
}
