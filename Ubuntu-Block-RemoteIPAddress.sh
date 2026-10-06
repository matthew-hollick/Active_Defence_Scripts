#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/Common/Ubuntu-ResponseRuntime.sh"
action=BlockRemoteIPAddress
target=
direction=both
fail() { local code=$?; write_action_result false "$action" "${target:-unknown}" "" "${1:-Action failed with exit code $code}"; exit 1; }
trap 'fail "Unexpected failure at line $LINENO"' ERR
while [[ $# -gt 0 ]]; do
  case $1 in
    --address) [[ $# -ge 2 ]] || fail 'Missing value for --address'; target=$2; shift 2 ;;
    --direction) [[ $# -ge 2 ]] || fail 'Missing value for --direction'; direction=${2,,}; shift 2 ;;
    *) fail "Unknown parameter: $1" ;;
  esac
done
[[ $direction == inbound || $direction == outbound || $direction == both ]] || fail 'Direction must be inbound, outbound, or both.'
assert_root || fail 'This action requires root privileges.'
assert_ubuntu || fail 'This action requires Ubuntu.'
require_command nft || fail 'Required command is unavailable: nft. Install the nftables package.'
normalized=$(assert_ip_address "$target") || fail "Invalid IP address: $target"
target=$normalized
family=ip
[[ $target == *:* ]] && family=ip6
nft list table inet elastic_response >/dev/null 2>&1 || nft add table inet elastic_response
nft list chain inet elastic_response input >/dev/null 2>&1 || nft 'add chain inet elastic_response input { type filter hook input priority -10; policy accept; }'
nft list chain inet elastic_response output >/dev/null 2>&1 || nft 'add chain inet elastic_response output { type filter hook output priority -10; policy accept; }'
existing=$(nft list table inet elastic_response 2>/dev/null || true)
if [[ $direction == inbound || $direction == both ]]; then
  marker="elastic-response-$family-in-$target"
  [[ $existing == *"$marker"* ]] || nft add rule inet elastic_response input "$family" saddr "$target" counter drop comment "$marker"
fi
if [[ $direction == outbound || $direction == both ]]; then
  marker="elastic-response-$family-out-$target"
  [[ $existing == *"$marker"* ]] || nft add rule inet elastic_response output "$family" daddr "$target" counter drop comment "$marker"
fi
trap - ERR
write_action_result true "$action" "$target" "direction=$direction;table=inet elastic_response" ""
