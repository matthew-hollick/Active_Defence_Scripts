#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/Common/Ubuntu-ResponseRuntime.sh"
action=QuarantineFile
target=
quarantine_directory=/var/lib/elastic-response/quarantine
fail() { local code=$?; write_action_result false "$action" "${target:-unknown}" "" "${1:-Action failed with exit code $code}"; exit 1; }
trap 'fail "Unexpected failure at line $LINENO"' ERR
while [[ $# -gt 0 ]]; do
  case $1 in
    --path) [[ $# -ge 2 ]] || fail 'Missing value for --path'; target=$2; shift 2 ;;
    --quarantine-directory) [[ $# -ge 2 ]] || fail 'Missing value for --quarantine-directory'; quarantine_directory=$2; shift 2 ;;
    *) fail "Unknown parameter: $1" ;;
  esac
done
[[ -n $target ]] || fail 'Required parameter missing: --path'
[[ $target = /* && $quarantine_directory = /* ]] || fail 'File and quarantine paths must be absolute.'
assert_root || fail 'This action requires root privileges.'
assert_ubuntu || fail 'This action requires Ubuntu.'
[[ -f $target && ! -L $target ]] || fail 'Target must be a regular file and not a symbolic link.'
hash=$(sha256sum -- "$target" | cut -d' ' -f1)
destination=$quarantine_directory/$hash.quarantine
[[ ! -e $destination ]] || fail "A quarantined file with SHA256 $hash already exists."
install -d -m 0700 -- "$quarantine_directory"
mv -- "$target" "$destination"
chmod 0600 -- "$destination"
trap - ERR
write_action_result true "$action" "$target" "sha256=$hash;quarantinePath=$destination" ""
