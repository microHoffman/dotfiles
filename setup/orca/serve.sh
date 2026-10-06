#!/usr/bin/env bash
set -euo pipefail

# The Home Manager unit supplies DISPLAY, XAUTHORITY, and the complete PATH.
app_dir="${ORCA_APP_DIR:-${XDG_DATA_HOME:-${HOME}/.local/share}/orca-install/current}"
port="${ORCA_PORT:-6768}"
scope="${ORCA_PAIRING_SCOPE:-runtime}"
args=()
case "$scope" in
  runtime) ;;
  mobile) args+=(--mobile-pairing) ;;
  *) printf 'orca-runtime: invalid ORCA_PAIRING_SCOPE: %s\n' "$scope" >&2; exit 1 ;;
esac
if [[ ! "$port" =~ ^[0-9]{1,5}$ ]]; then
  printf 'orca-runtime: invalid ORCA_PORT\n' >&2
  exit 1
fi
port=$((10#$port))
if ((port < 1 || port > 65535)); then
  printf 'orca-runtime: invalid ORCA_PORT\n' >&2
  exit 1
fi
[ -x "$app_dir/AppRun" ] || {
  printf 'orca-runtime: install the pinned release with setup/orca/install.sh first\n' >&2
  exit 1
}

display_ready=false
for ((attempt = 0; attempt < 30; attempt++)); do
  if xdpyinfo >/dev/null 2>&1; then
    display_ready=true
    break
  fi
  sleep 1
done
if [ "$display_ready" != true ]; then
  printf 'orca-runtime: authenticated display is not ready\n' >&2
  exit 1
fi

address=""
for ((attempt = 0; attempt < 30; attempt++)); do
  if status_json="$(tailscale status --json --peers=false 2>/dev/null)"; then
    address="$(jq -r '
      if .BackendState == "Running" then
        [.Self.TailscaleIPs[]? | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$"))][0] // ""
      else "" end
    ' <<<"$status_json")"
    [ -z "$address" ] || break
  fi
  sleep 2
done
if [ -z "$address" ]; then
  printf 'orca-runtime: Tailscale did not become ready with an IPv4 address\n' >&2
  exit 1
fi
# An upstream fallback port would not match the interface-specific firewall rule.
if [ -n "$(ss -H -ltn "sport = :${port}")" ]; then
  printf 'orca-runtime: TCP port %s is already in use\n' "$port" >&2
  exit 1
fi

exec "$app_dir/AppRun" serve --port "$port" --pairing-address "$address" \
  --json "${args[@]}"
