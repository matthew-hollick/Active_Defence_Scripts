#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/Common/Ubuntu-ResponseRuntime.sh"
action=DisableLocalUserAccount
target=
fail() { local code=$?; write_action_result false "$action" "${target:-unknown}" "" "${1:-Action failed with exit code $code}"; exit 1; }
trap 'fail "Unexpected failure at line $LINENO"' ERR
while [[ $# -gt 0 ]]; do
  case $1 in
    --name) [[ $# -ge 2 ]] || fail 'Missing value for --name'; target=$2; shift 2 ;;
    *) fail "Unknown parameter: $1" ;;
  esac
done
[[ -n $target ]] || fail 'Required parameter missing: --name'
assert_root || fail 'This action requires root privileges.'
assert_ubuntu || fail 'This action requires Ubuntu.'
require_command usermod || fail 'Required command is unavailable: usermod'
entry=$(getent passwd "$target") || fail "Local user not found: $target"
uid=$(cut -d: -f3 <<<"$entry")
[[ $uid -ne 0 ]] || fail 'Refusing to disable the root account.'
previous=$(passwd -S "$target" 2>/dev/null || true)
usermod --lock --expiredate 1 -- "$target"
trap - ERR
write_action_result true "$action" "$target" "previousStatus=$previous" ""
