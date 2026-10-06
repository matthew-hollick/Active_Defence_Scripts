#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/Common/Ubuntu-ResponseRuntime.sh"
action=DisableSystemdTimer
target=
fail() { local code=$?; write_action_result false "$action" "${target:-unknown}" "" "${1:-Action failed with exit code $code}"; exit 1; }
trap 'fail "Unexpected failure at line $LINENO"' ERR
while [[ $# -gt 0 ]]; do
  case $1 in
    --unit) [[ $# -ge 2 ]] || fail 'Missing value for --unit'; target=$2; shift 2 ;;
    *) fail "Unknown parameter: $1" ;;
  esac
done
[[ $target =~ ^[A-Za-z0-9_.@-]+\.timer$ ]] || fail 'Required --unit must be a valid .timer unit name.'
assert_root || fail 'This action requires root privileges.'
assert_ubuntu || fail 'This action requires Ubuntu.'
require_command systemctl || fail 'Required command is unavailable: systemctl'
systemctl cat "$target" >/dev/null 2>&1 || fail "Timer unit not found: $target"
previous=$(systemctl is-active "$target" 2>/dev/null || true)
systemctl disable --now "$target"
trap - ERR
write_action_result true "$action" "$target" "previousState=$previous" ""
