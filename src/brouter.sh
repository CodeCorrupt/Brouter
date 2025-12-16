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
  brouter.sh [--test] [--config <file>] <url>

Options:
  --test          Print the command that would be executed, without running it
  --config <file> Use the specified config file instead of the default

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
  local test_mode=false
  local config=""

  if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
    usage
    exit 0
  fi

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --test)
        test_mode=true
        shift
        ;;
      --config)
        if [[ -z "${2:-}" ]]; then
          echo "Error: --config requires a file argument" >&2
          exit 1
        fi
        config="$2"
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done

  if [[ $# -ne 1 ]]; then
    usage
    exit 1
  fi

  local url="$1"

  if [[ -z "$config" ]]; then
    if ! config="$(pick_config)"; then
      echo "No config found. Create one of:" >&2
      printf '  - %s\n' "${CONFIG_CANDIDATES[@]}" >&2
      exit 2
    fi
  elif [[ ! -f "$config" ]]; then
    echo "Error: Config file not found: $config" >&2
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

      if [[ "$test_mode" == true ]]; then
        echo "Matched: $regex"
        echo "Command: $rest \"$url\""
        exit 0
      fi

      # Run via eval so quotes in config work, then exit.
      eval "$rest \"\$url\""
      exit 0
    fi
  done <"$config"

  log "No rule matched; exiting"
  exit 3
}

main "$@"
