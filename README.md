# Elastic Defend Windows and Ubuntu Response Script Library

This repository contains explicitly named Windows PowerShell and Ubuntu Bash response actions for the Elastic Security Script Library. Elastic Defend executes them through the `runscript` response action. Elastic Defend `runscript` is generally available in Elastic Stack 9.4 and Elastic Cloud Serverless.

Every action name and executable starts with `Windows-` or `Ubuntu-`. This prevents an analyst from confusing platform-specific implementations. Elastic Script Library metadata must also use the prefixed display names from `catalog.json`.

Each action writes one compressed JSON object to standard output and exits `0` on success or `1` on failure. Results include `success`, `action`, `target`, `host`, `timestampUtc`, `details`, and `error`.

## Requirements

### Elastic

- Elastic Defend installed on each target endpoint.
- A subscription or Serverless feature tier that includes Script Library and response actions.
- **Elastic Defend Scripts Management** privilege to upload or replace scripts.
- **Execute Operations** privilege to invoke `runscript`.
- Read access to **Response Actions History** to monitor execution and output.
- Elastic Stack 9.4 or later when running Script Library actions through Elastic Defend.

### Windows

- Windows PowerShell 5.1.
- Elastic Defend running with its normal elevated endpoint privileges.
- AD actions must target an enrolled domain controller with the `ActiveDirectory` PowerShell module installed.

### Ubuntu

- Ubuntu with Bash, systemd, Python 3, and standard GNU user/file utilities.
- Elastic Defend running as root, as expected for endpoint protection.
- `nft` from the `nftables` package is required only by `Ubuntu-Block-RemoteIPAddress.sh`. The script fails safely if it is unavailable; it does not install packages.
- Ubuntu actions read `/etc/os-release` and refuse to run when `ID` is not `ubuntu`.

## Action inventory

### Windows actions

| Script Library name | Purpose | Input example |
|---|---|---|
| Windows - Disable AD User Account | Disable an AD user on a DC | `-Identity "alice"` |
| Windows - Disable AD Computer Account | Disable an AD computer on a DC | `-Identity "WORKSTATION01"` |
| Windows - Remove AD User Group Memberships | Remove direct memberships except a preserve list | `-Identity "alice" -PreserveGroups "Domain Users,IR Hold"` |
| Windows - Disable Local User Account | Disable a local Windows account | `-Name "localuser"` |
| Windows - Stop Process By ID | Force-stop one process | `-ProcessId 1234` |
| Windows - Stop And Disable Service | Stop and disable a Windows service | `-Name "SuspiciousService"` |
| Windows - Block Remote IP Address | Add inbound/outbound Windows Firewall block rules | `-Address "203.0.113.10" -Direction "Both"` |
| Windows - Firewall Restrict Host Fallback | Restrict firewall profile defaults | `-AllowRemoteAddress "10.0.0.10,10.0.0.11"` |
| Windows - Restore Firewall After Restriction | Restore saved firewall profile defaults | No input |
| Windows - Disable Scheduled Task | Disable a scheduled task | `-TaskName "SuspiciousTask" -TaskPath "\"` |
| Windows - Quarantine File | Hash and move a file into local quarantine | `-Path "C:\Temp\suspicious.exe"` |

### Ubuntu actions

| Script Library name | Purpose | Input example |
|---|---|---|
| Ubuntu - Disable Local User Account | Lock and expire a non-root local account | `--name localuser` |
| Ubuntu - Stop Process By ID | Send `SIGKILL` to one PID | `--process-id 1234` |
| Ubuntu - Stop And Disable Service | Stop and disable a systemd service/unit | `--name suspicious.service` |
| Ubuntu - Block Remote IP Address | Add idempotent nftables drop rules | `--address 203.0.113.10 --direction both` |
| Ubuntu - Disable Systemd Timer | Stop and disable a systemd timer | `--unit suspicious.timer` |
| Ubuntu - Quarantine File | Hash and move a regular file into root-only quarantine | `--path /tmp/suspicious.bin` |

The complete machine-readable contract is in `catalog.json`, including exact filenames, packages, executable paths, parameters, allowed values, and defaults.

## Build Elastic upload packages

Every action depends on one platform runtime:

- Windows: `Common/Windows-ResponseRuntime.psm1`
- Ubuntu: `Common/Ubuntu-ResponseRuntime.sh`

Uploading an action file by itself will fail because its runtime will be absent. Build one ZIP per action from the repository root:

```powershell
powershell.exe -NoProfile -File .\Windows-Build-ElasticPackages.ps1
```

The build removes stale generated ZIPs and creates the current packages under `packages/`. Each ZIP contains exactly one platform-prefixed action and its matching runtime.

## Upload to Elastic Script Library

For every `catalog.json` action:

1. Open **Security → Script library** and choose **Upload script**.
2. Upload the action's `package` ZIP.
3. Select **Archive**.
4. Use the exact platform-prefixed `name` from the catalog.
5. Select only the catalog platform: **Windows** for `.ps1` actions or **Linux** for Ubuntu `.sh` actions.
6. Set **Path to executable file** to `executablePath` from the catalog.
7. Enable **This script requires user input** when `parameters` is non-empty. Leave it disabled for the Windows firewall restore action.
8. Select **Remediation Action** as the category.
9. Add the catalog's input example to the Script Library instructions.

Elastic rejects an uploaded file when its SHA256 matches an existing Script Library object. Every generated archive has distinct action content.

## Run from the response console

Elastic passes `--inputParams` as command-line arguments. Parameters are platform-specific: Windows uses PowerShell names beginning with one dash; Ubuntu uses Bash options beginning with two dashes.

```text
runscript --script="Windows - Disable Local User Account" --inputParams="-Name localuser" --timeout="2m" --comment="IR-1234 disable confirmed account"
runscript --script="Ubuntu - Disable Local User Account" --inputParams="--name localuser" --timeout="2m" --comment="IR-1234 disable confirmed account"
runscript --script="Ubuntu - Block Remote IP Address" --inputParams="--address 203.0.113.10 --direction both" --timeout="2m" --comment="IR-1234 block confirmed C2"
```

`--script` is required. `--inputParams` is optional only for actions without parameters. `--timeout` accepts values such as `30s`, `2m`, and `1h`, and defaults to four hours. Pending actions can execute after an offline endpoint reconnects and normally expire after two weeks. Do not submit a response whose parameters would become unsafe if execution is delayed.

## Run through the Kibana API

Use `POST /api/endpoint/action/run_script`, or `/s/{space_id}/api/endpoint/action/run_script` for a non-default Kibana space. The API accepts up to 250 endpoint IDs. `scriptId` is the Script Library object ID, not its display name. `scriptInput` is an optional raw argument string with a maximum length of 8192 characters.

Windows example:

```json
{
  "agent_type": "endpoint",
  "endpoint_ids": ["WINDOWS-ENDPOINT-ID"],
  "comment": "IR-1234 confirmed compromised account",
  "parameters": {
    "scriptId": "WINDOWS-SCRIPT-LIBRARY-ID",
    "scriptInput": "-Name \"localuser\""
  }
}
```

Ubuntu example:

```json
{
  "agent_type": "endpoint",
  "endpoint_ids": ["UBUNTU-ENDPOINT-ID"],
  "comment": "IR-1234 block confirmed C2",
  "parameters": {
    "scriptId": "UBUNTU-SCRIPT-LIBRARY-ID",
    "scriptInput": "--address 203.0.113.10 --direction both"
  }
}
```

Optional `alert_ids` and `case_ids` associate the response with alerts or cases. Authenticate to Kibana with an appropriately scoped API key or supported user identity. Use `Content-Type: application/json` and `kbn-xsrf: true` where required.

## Parameter and secret rules

- Pass only parameters documented in `catalog.json`.
- Quote values containing spaces, commas, or shell-significant characters.
- Never pass passwords, private keys, access tokens, API keys, or other secrets through `--inputParams` or `scriptInput`; arguments can be retained in response history, logs, and endpoint telemetry.
- Do not append pipelines, redirections, command substitutions, script blocks, arbitrary shell commands, or encoded commands.
- Windows list parameters are comma-separated quoted strings to avoid native PowerShell array-binding ambiguity.
- Ubuntu scripts reject unknown options and validate identifiers, PIDs, absolute paths, directions, and IP addresses.
- Windows mutating scripts support `-WhatIf`. Do not include it in production remediation.

## Platform-specific behavior

### Windows AD

Local administrator or SYSTEM rights on a member endpoint do not grant AD modification rights. The AD scripts refuse to run outside a domain controller. Dispatch them only to approved enrolled DC endpoint IDs. Disabling a user does not revoke all cloud/application sessions, and AD replication is asynchronous. Use the identity provider's session-revocation workflow separately and verify replicated state.

### Ubuntu accounts

`Ubuntu-Disable-LocalUserAccount.sh` uses `usermod --lock --expiredate 1`. It refuses UID 0. It does not terminate existing sessions or processes; isolate or terminate those separately when required. It operates on identities resolvable by `getent`, but directory-backed identity providers may require remediation at the identity source instead of the endpoint.

### Ubuntu firewall

`Ubuntu-Block-RemoteIPAddress.sh` creates an `inet elastic_response` nftables table with input and output base chains, then adds commented IPv4 or IPv6 drop rules. Repeating the same address/direction is idempotent. The script changes the active ruleset but does not persist it across reboot because Ubuntu persistence policy varies. Treat the block as immediate incident containment and implement persistence centrally if required.

### File quarantine

Windows quarantine defaults to `%ProgramData%\SIEMResponse\Quarantine`. Ubuntu quarantine defaults to `/var/lib/elastic-response/quarantine` with directory mode `0700` and file mode `0600`. Both actions hash before moving and refuse to overwrite an existing object with the same SHA256. Quarantine can fail for locked files, immutable files, mount restrictions, or mandatory access-control policy.

## Host isolation

Use Elastic Defend's native `isolate` and `release` actions for both Windows and Ubuntu. They are designed to preserve Elastic management connectivity.

The Windows firewall restriction/restore pair is retained only as a fallback. It is not a hard isolation boundary because existing explicit allow rules may remain effective, and incorrect management addresses can disconnect Elastic. There is no Ubuntu custom isolation script in this library; use Elastic's native isolation rather than introducing a distribution-specific firewall policy that could sever agent control.

## Operational safeguards

- Restrict Script Library management and Execute Operations to dedicated response roles.
- Require an incident ID, analyst reason, and approval policy before destructive actions.
- Associate API actions with `alert_ids` or `case_ids` when available.
- Test every ZIP against representative non-production Windows and Ubuntu endpoint images.
- Test AD actions in a non-production domain.
- Review Response Actions History and retain the JSON result as evidence.
- Monitor Script Library uploads and replacements because replacement changes future executions.
- Prefer Elastic native `kill-process`, `isolate`, `release`, `scan`, and `get-file` when they directly satisfy the objective.

References:

- [Elastic Script library](https://www.elastic.co/docs/solutions/security/endpoint-response-actions/script-library)
- [Elastic Defend endpoint response actions](https://www.elastic.co/docs/solutions/security/endpoint-response-actions)
- [Kibana run script API](https://www.elastic.co/docs/api/doc/kibana/operation/operation-runscriptaction)
