#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/Common/Ubuntu-ResponseRuntime.sh"
action=StopProcessById
target=
fail() { local code=$?; write_action_result false "$action" "${target:-unknown}" "" "${1:-Action failed with exit code $code}"; exit 1; }
trap 'fail "Unexpected failure at line $LINENO"' ERR
while [[ $# -gt 0 ]]; do
  case $1 in
    --process-id) [[ $# -ge 2 ]] || fail 'Missing value for --process-id'; target=$2; shift 2 ;;
    *) fail "Unknown parameter: $1" ;;
  esac
done
[[ $target =~ ^[1-9][0-9]*$ ]] || fail 'Required --process-id must be a positive integer.'
[[ $target -ne 1 && $target -ne $$ && $target -ne $PPID ]] || fail 'Refusing to terminate PID 1 or the response process tree.'
assert_root || fail 'This action requires root privileges.'
assert_ubuntu || fail 'This action requires Ubuntu.'
[[ -r /proc/$target/comm ]] || fail "Process not found: $target"
name=$(<"/proc/$target/comm")
kill -KILL "$target"
trap - ERR
write_action_result true "$action" "$target" "processName=$name" ""
