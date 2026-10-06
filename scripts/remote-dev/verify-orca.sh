#!/usr/bin/env bash
set -euo pipefail

failures=0
check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'ok   %s\n' "$label"
  else
    printf 'fail %s\n' "$label" >&2
    failures=$((failures + 1))
  fi
}

runtime_ready() {
  orca-ide status --json | jq -e '.ok and .result.runtime.reachable and .result.runtime.state == "ready"'
}

linger_enabled() {
  [ "$(loginctl show-user "$USER" -p Linger --value)" = yes ]
}

check 'Orca CLI runs' orca-ide --version
check 'Codex CLI runs' codex --version
check 'Claude CLI runs (login is optional)' claude --version
check 'Orca runtime is enabled at login/boot' systemctl --user is-enabled --quiet orca-runtime.service
check 'Orca runtime is active' systemctl --user is-active --quiet orca-runtime.service
check 'Orca virtual display is active' systemctl --user is-active --quiet orca-virtual-display.service
check 'Orca RPC is ready' runtime_ready
check 'Tailscale has an IPv4 address' tailscale ip -4
check 'user lingering is enabled' linger_enabled

printf 'info Claude authentication is optional and is not a readiness requirement.\n'
if [ "$failures" -ne 0 ]; then
  printf '%s Orca checks failed.\n' "$failures" >&2
  exit 1
fi
