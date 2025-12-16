#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Brouter"

# Config search order (first existing wins)
CONFIG_CANDIDATES=(
  "${XDG_CONFIG_HOME:-$HOME/.config}/brouter/config"
  "$HOME/Library/Application Support/Brouter/config"
)

usage() {
  cat <<'EOF'
Usage:
  brouter.sh <url>

Config format (one rule per line):
  <regex> <command...>

Notes:
- Lines starting with # are ignored.
- The first matching regex wins.
- The selected command is executed with the URL appended as the final argument.

Examples:
  # Work links in Chrome
  ^https://(corp\\.|jira\\.|confluence\\.) open -a "Google Chrome"

  # Everything else in Safari
  .* open -a "Safari"
EOF
}

log() {
  # Log to user's Library Logs
  local log_dir="$HOME/Library/Logs/${APP_NAME}"
  mkdir -p "$log_dir"
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$log_dir/brouter.log"
}

pick_config() {
  local candidate
  for candidate in "${CONFIG_CANDIDATES[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  return 1
}

main() {
  if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -ne 1 ]]; then
    usage
    exit 0
  fi

  local url="$1"

  local config
  if ! config="$(pick_config)"; then
    echo "No config found. Create one of:" >&2
    printf '  - %s\n' "${CONFIG_CANDIDATES[@]}" >&2
    exit 2
  fi

  log "URL: $url"
  log "Config: $config"

  local line regex rest
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim leading/trailing whitespace
    line="${line#${line%%[![:space:]]*}}"
    line="${line%${line##*[![:space:]]}}"

    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue

    # Split into: regex + rest-of-line (command)
    regex="${line%%[[:space:]]*}"
    rest="${line#"$regex"}"
    rest="${rest#${rest%%[![:space:]]*}}"

    if [[ -z "$rest" ]]; then
      continue
    fi

    if [[ "$url" =~ $regex ]]; then
      log "Matched regex: $regex"
      log "Command: $rest \"$url\""

      # Run via eval so quotes in config work, then exit.
      eval "$rest \"\$url\""
      exit 0
    fi
  done <"$config"

  log "No rule matched; exiting"
  exit 3
}

main "$@"
