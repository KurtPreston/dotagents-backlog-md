# Conflict handling for backlog-md-sync, sourced by it.
# resolve_rebase_conflicts asks Copilot CLI to merge task files the rebase stopped on, and aborts the
# rebase when it can't. renumber_duplicate_ids gives local tasks that collide with remote IDs new ones.

# Ask Copilot to merge one conflicted task file in place, rejecting output that isn't a clean task file
merge_task_file() {
  local file="$1" prompt output id
  [[ "$file" == *.md ]] && command -v copilot >/dev/null || return 1
  prompt="$(cat "$plugin_dir/prompts/resolve-conflict.md")"$'\n\nConflicted file `'"$file"$'`:\n\n'"$(cat "$file")"
  output="$(copilot -p "$prompt" -s --no-custom-instructions --disable-builtin-mcps --no-auto-update \
    --disable-client-telemetry --deny-tool shell --deny-tool write --deny-tool url 2>/dev/null)" || return 1
  output="$(printf '%s\n' "$output" | sed '/^```/d')"

  # Accept only a frontmatter file with no conflict markers that keeps the task's ID
  id="$(git show "REBASE_HEAD:$file" 2>/dev/null | sed -nE 's/^id:[[:space:]]*['\''"]?([^'\''"]*)['\''"]?[[:space:]]*$/\1/p' | head -n 1)"
  [[ "$output" == ---* ]] || return 1
  ! grep -qE '^(<<<<<<<|=======|>>>>>>>)' <<<"$output" || return 1
  [[ -z "$id" ]] || grep -qE "^id:[[:space:]]*['\"]?$id['\"]?[[:space:]]*$" <<<"$output" || return 1

  # Write it, and make sure Backlog.md can still read the task before staging it
  printf '%s\n' "$output" >"$file"
  [[ -z "$id" ]] || BACKLOG_CWD=. backlog task view "$id" --plain >/dev/null 2>&1 || return 1
  git add -- "$file"
}

# Merge the conflicted files at each stopped rebase step, or abort and explain
resolve_rebase_conflicts() {
  local steps=0 files file stages
  while [[ -d "$(git rev-parse --git-path rebase-merge)" || -d "$(git rev-parse --git-path rebase-apply)" ]]; do
    steps=$((steps + 1))
    files="$(git -c core.quotepath=false diff --name-only --diff-filter=U)"
    if [[ "$steps" -gt 50 || -z "$files" ]]; then
      abort_rebase
      return 1
    fi

    # Merge files both sides changed; a file deleted on one side needs a person
    while IFS= read -r file; do
      stages="$(git ls-files -u -- "$file" | cut -f1 | awk '{ print $3 }' | sort -u | tr -d '\n')"
      if [[ "$stages" != *2*3* ]] || ! merge_task_file "$file"; then
        abort_rebase
        return 1
      fi
      say "merged conflicting edits to $file"
    done <<<"$files"

    # Continue to the next local commit, which may stop again
    GIT_EDITOR=true git rebase --continue >/dev/null 2>&1 || true
  done
}

# Abort a stopped rebase so the board shows the local version, and report the conflicted files
abort_rebase() {
  local files
  files="$(git -c core.quotepath=false diff --name-only --diff-filter=U | sed 's/^/  /')"
  git rebase --abort
  echo "backlog-md-sync: couldn't merge with $remote_ref automatically; resolve by hand with: git -C \"$tasks_dir\" pull --rebase" >&2
  [[ -z "$files" ]] || printf '%s\n' "$files" >&2
}

# Give local tasks that share an ID with a remote task the next free ID, and commit the change
renumber_duplicate_ids() {
  local renames count old new subject
  renames="$(node "$plugin_dir/lib/renumber.mjs" "$remote_ref")" || return 1
  [[ -n "$renames" ]] || return 0
  git add -A -- backlog

  # Name a single renumbering in the subject, or list several in the body
  count="$(wc -l <<<"$renames" | tr -d ' ')"
  if [[ "$count" -eq 1 ]]; then
    read -r old new <<<"$renames"
    subject="$old → $new: renumbered after sync"
    git commit -q -m "$subject"
  else
    subject="Renumber $count tasks after sync"
    git commit -q -m "$subject" -m "$(while read -r old new; do echo "- $old → $new"; done <<<"$renames")"
  fi
  say "$subject"
}
