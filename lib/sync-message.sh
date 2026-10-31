# Build a plain commit message for the staged changes in a Backlog.md board, one line per change.
# Task files read as "TASK-6 Board-sync: To Do → In Progress", using the ID and title from the filename.
# One change becomes the subject; several become "Update N tasks" with a line each in the body.
# Source this file, then call: sync_commit_message   (from the board's root, after `git add -A`)

# Describe one staged task or board file, given its git status letter and old and new paths
describe_change() {
  local status="$1" old="$2" new="$3"
  local name id title action

  # Split a task filename such as "task-6 - Board-sync.md" into its ID and title
  name="$(basename "$new" .md)"
  if [[ "$name" =~ ^([A-Za-z]+-[0-9.]+)\ -\ (.*)$ ]]; then
    id="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')"
    title="${BASH_REMATCH[2]}"
  else
    echo "Update $new"
    return
  fi

  # Name what happened to the task, preferring a status change when there is one
  case "$status" in
    A) action="created" ;;
    D) action="deleted" ;;
    R*)
      case "$new" in
        */archive/*) action="archived" ;;
        */completed/*) action="completed" ;;
        *) action="renamed" ;;
      esac
      ;;
    *)
      local from to
      from="$(git diff --cached -U0 -- "$new" | sed -nE "s/^-status:[[:space:]]*['\"]?([^'\"]*)['\"]?[[:space:]]*$/\1/p" | head -n 1)"
      to="$(git diff --cached -U0 -- "$new" | sed -nE "s/^\+status:[[:space:]]*['\"]?([^'\"]*)['\"]?[[:space:]]*$/\1/p" | head -n 1)"
      if [[ -n "$from" && -n "$to" ]]; then
        action="$from → $to"
      else
        action="updated"
      fi
      ;;
  esac
  echo "$id $title: $action"
}

# Describe every staged change, then pick a subject and body
sync_commit_message() {
  local lines=() status old new
  while IFS=$'\t' read -r status old new; do
    lines+=("$(describe_change "$status" "$old" "${new:-$old}")")
  done < <(git -c core.quotepath=false diff --cached --name-status -M)

  # A single change is the whole message; several get a count and a list
  if [[ "${#lines[@]}" -eq 1 ]]; then
    printf '%s\n' "${lines[0]}"
  else
    local noun="tasks" line
    for line in "${lines[@]}"; do
      [[ "$line" != "Update "* ]] || noun="files"
    done
    printf 'Update %d %s\n\n' "${#lines[@]}" "$noun"
    printf -- '- %s\n' "${lines[@]}"
  fi
}
