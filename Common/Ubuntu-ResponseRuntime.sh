#!/usr/bin/env bash
set -Eeuo pipefail

assert_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    printf '%s\n' 'This action requires root privileges.' >&2
    return 1
  fi
}

assert_ubuntu() {
  if [[ ! -r /etc/os-release ]]; then
    printf '%s\n' 'Cannot identify the operating system.' >&2
    return 1
  fi
  . /etc/os-release
  if [[ ${ID:-} != ubuntu ]]; then
    printf 'This action requires Ubuntu; detected %s.\n' "${ID:-unknown}" >&2
    return 1
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command is unavailable: %s\n' "$1" >&2
    return 1
  fi
}

assert_ip_address() {
  require_command python3
  python3 - "$1" <<'PY'
import ipaddress
import sys
try:
    print(ipaddress.ip_address(sys.argv[1]))
except ValueError:
    raise SystemExit(1)
PY
}

write_action_result() {
  local success=$1 action=$2 target=$3 details=${4:-} error=${5:-}
  require_command python3
  python3 - "$success" "$action" "$target" "$(hostname)" "$details" "$error" <<'PY'
import datetime
import json
import sys
success, action, target, host, details, error = sys.argv[1:]
print(json.dumps({
    "success": success == "true",
    "action": action,
    "target": target,
    "host": host,
    "timestampUtc": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
    "details": details,
    "error": error or None,
}, separators=(",", ":")))
PY
}
