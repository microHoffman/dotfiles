#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s runtime|mobile\nRestarts the Orca user service and prints a fresh private pairing link.\n' "${0##*/}"
}
if [ "$#" -ne 1 ]; then usage >&2; exit 2; fi
case "$1" in
  runtime|mobile) scope="$1" ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

# Always clear this temporary choice, including when restart or readiness fails.
trap 'systemctl --user unset-environment ORCA_PAIRING_SCOPE' EXIT
systemctl --user set-environment "ORCA_PAIRING_SCOPE=$scope"
systemctl --user reset-failed orca-runtime.service
systemctl --user restart orca-runtime.service
runtime_pid="$(systemctl --user show orca-runtime.service -p MainPID --value)"
[ "${runtime_pid:-0}" -gt 0 ] || { printf 'Orca did not start.\n' >&2; exit 1; }
# Electron registers an app scope, so its stdout is not attributed to our service.
started="$(systemctl --user show orca-runtime.service -p ExecMainStartTimestamp --value)"

for ((attempt = 0; attempt < 90; attempt++)); do
  ready="$(journalctl --user "_PID=$runtime_pid" --since "$started" --no-pager -o cat |
    jq -Rc 'fromjson? | select(.type == "orca_server_ready" and .schemaVersion == 1)' |
    tail -n 1)"
  if [ -n "$ready" ]; then
    if ! jq -e '.pairing.available == true' <<<"$ready" >/dev/null; then
      jq -r '.pairing.reason, .pairing.guidance' <<<"$ready" >&2
      exit 1
    fi
    jq -r '"Private pairing link (treat as a credential):", .pairing.url,
      (.pairing.webClientUrl // empty), (.pairing.qr // empty)' <<<"$ready"
    exit 0
  fi
  if ! systemctl --user is-active --quiet orca-runtime.service; then
    printf 'Orca stopped before becoming ready; inspect its user journal.\n' >&2
    exit 1
  fi
  sleep 1
done
printf 'Orca did not report readiness within 90 seconds. Inspect its user journal.\n' >&2
exit 1
