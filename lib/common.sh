# Shared setup for the backlog-md scripts, sourced after each sets plugin_dir.
# Adds common tool folders to PATH for launchd, finds the board in BACKLOG_CWD (env, then ~/.localrc,
# then ~/Code/tasks) as tasks_dir, and loads sync settings from config.jsonc into SYNC_* variables.
# BACKLOG_MD_CONFIG overrides the config path, for tests.

# Make Homebrew and mise-managed tools available when launchd runs a script with a bare PATH
export PATH="$PATH:$HOME/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin"

# Find the board, reading just the BACKLOG_CWD line from ~/.localrc when the environment lacks it,
# so the file's other secrets never reach child processes such as Copilot
if [[ -z "${BACKLOG_CWD:-}" && -f "$HOME/.localrc" ]]; then
  BACKLOG_CWD="$(sed -nE 's/^(export[[:space:]]+)?BACKLOG_CWD=["'\'']?([^"'\'']*)["'\'']?[[:space:]]*$/\2/p' "$HOME/.localrc" | tail -n 1)"
  BACKLOG_CWD="${BACKLOG_CWD/#\~/$HOME}"
  BACKLOG_CWD="${BACKLOG_CWD/#\$HOME/$HOME}"
fi
tasks_dir="${BACKLOG_CWD:-$HOME/Code/tasks}"

# Load sync settings, which default to disabled when there's no config.jsonc
if ! command -v node >/dev/null; then
  echo "backlog-md: node is not on PATH; it's needed to read $plugin_dir/config.jsonc" >&2
  exit 1
fi
sync_config="$(node "$plugin_dir/lib/config.mjs" "${BACKLOG_MD_CONFIG:-}")"
eval "$sync_config"
