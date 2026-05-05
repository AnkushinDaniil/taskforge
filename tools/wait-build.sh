#!/usr/bin/env bash
# Mac-side helper: poll the VM's build agent status file after a `git push`.
#
# Usage:
#   tools/wait-build.sh              # waits for the agent to process HEAD
#   tools/wait-build.sh --timeout 300
#
# Pre-requisites:
#   - SSH to the VM is configured at port 2222 with key auth (see README).
#   - The build agent is registered on the VM (tools/install-agent.ps1).
#   - The Delphi IDE is open in the VM with TaskForge.groupproj loaded.

set -euo pipefail

SSH_HOST="${TASKFORGE_SSH_HOST:-daniil@127.0.0.1}"
SSH_PORT="${TASKFORGE_SSH_PORT:-2222}"
SSH_KEY="${TASKFORGE_SSH_KEY:-$HOME/.ssh/id_ed25519}"
TIMEOUT_SEC=300
POLL_SEC=4

while [[ $# -gt 0 ]]; do
    case "$1" in
        --timeout) TIMEOUT_SEC="$2"; shift 2 ;;
        --host)    SSH_HOST="$2";    shift 2 ;;
        --port)    SSH_PORT="$2";    shift 2 ;;
        --key)     SSH_KEY="$2";     shift 2 ;;
        -h|--help)
            sed -n '1,/^$/p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

target_sha=$(git rev-parse HEAD)
echo "Waiting for build of $target_sha (timeout ${TIMEOUT_SEC}s)..."

deadline=$(( $(date +%s) + TIMEOUT_SEC ))
ssh_cmd=(ssh -p "$SSH_PORT" -o BatchMode=yes -i "$SSH_KEY" "$SSH_HOST")

while [[ $(date +%s) -lt $deadline ]]; do
    json=$("${ssh_cmd[@]}" 'type C:\\dev\\taskforge\\bin\\.build-status.json 2>nul' 2>/dev/null || true)
    if [[ -n "$json" ]]; then
        # Extract sha and outcome with portable shell tooling
        got_sha=$(printf '%s' "$json" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("sha",""))' 2>/dev/null || echo)
        outcome=$(printf '%s' "$json" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("outcome",""))' 2>/dev/null || echo)
        if [[ "$got_sha" == "$target_sha" ]]; then
            duration=$(printf '%s' "$json" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("duration_sec",""))' 2>/dev/null || echo)
            echo "Agent reports: outcome=$outcome  duration=${duration}s  sha=$got_sha"
            if [[ "$outcome" == "success" ]]; then
                exit 0
            fi
            echo
            echo "Status JSON:"
            printf '%s\n' "$json"
            exit 1
        fi
    fi
    sleep "$POLL_SEC"
done

echo "Timed out waiting for the agent to process $target_sha." >&2
echo "Latest status:" >&2
printf '%s\n' "${json:-<no status file yet>}" >&2
exit 124
