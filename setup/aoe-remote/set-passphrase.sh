#!/usr/bin/env bash
set -euo pipefail

environment_file="${AOE_DASHBOARD_ENV_FILE:-${XDG_CONFIG_HOME:-${HOME}/.config}/aoe-dashboard/serve.env}"
environment_dir="$(dirname -- "$environment_file")"

if [ ! -t 0 ]; then
  printf 'set-passphrase: an interactive terminal is required\n' >&2
  exit 1
fi

if [ -e "$environment_file" ]; then
  printf 'A dashboard passphrase already exists. Rotation signs out connected devices after the dashboard restarts.\n'
  read -r -p 'Type ROTATE to continue: ' rotate_confirmation
  if [ "$rotate_confirmation" != "ROTATE" ]; then
    printf 'Passphrase unchanged.\n'
    exit 0
  fi
fi

printf 'Paste a unique password-manager-generated passphrase.\n'
printf 'Requirements: at least 24 characters; only A-Z, a-z, 0-9, underscore, and hyphen.\n'
read -r -s -p 'Passphrase: ' passphrase
printf '\n'
read -r -s -p 'Confirm passphrase: ' confirmation
printf '\n'

if [ "$passphrase" != "$confirmation" ]; then
  printf 'set-passphrase: values do not match\n' >&2
  exit 1
fi
if [ "${#passphrase}" -lt 24 ]; then
  printf 'set-passphrase: passphrase must contain at least 24 characters\n' >&2
  exit 1
fi
if [[ ! "$passphrase" =~ ^[A-Za-z0-9_-]+$ ]]; then
  printf 'set-passphrase: passphrase contains unsupported characters\n' >&2
  exit 1
fi

install -d -m 700 -- "$environment_dir"
temporary_file="$(mktemp "${environment_dir}/.serve.env.XXXXXX")"
cleanup() {
  rm -f -- "$temporary_file"
}
trap cleanup EXIT

chmod 600 "$temporary_file"
printf 'AOE_SERVE_PASSPHRASE=%s\n' "$passphrase" >"$temporary_file"
mv -- "$temporary_file" "$environment_file"
trap - EXIT
unset passphrase confirmation

printf 'Stored the dashboard passphrase in %s with mode 0600.\n' "$environment_file"

if command -v systemctl >/dev/null 2>&1 \
  && systemctl --user is-active --quiet aoe-dashboard.service; then
  printf 'Restarting the active dashboard so the new passphrase takes effect immediately.\n'
  if ! systemctl --user restart aoe-dashboard.service; then
    printf 'set-passphrase: systemd could not restart the dashboard\n' >&2
    printf 'Disable public access with: tailscale funnel --https=443 off\n' >&2
    exit 1
  fi

  dashboard_ready=false
  for _ in $(seq 1 60); do
    if systemctl --user is-active --quiet aoe-dashboard.service \
      && command -v aoe >/dev/null 2>&1 \
      && aoe serve --status >/dev/null 2>&1; then
      dashboard_ready=true
      break
    fi
    sleep 1
  done

  if [ "$dashboard_ready" != true ]; then
    systemctl --user stop aoe-dashboard.service || true
    printf 'set-passphrase: the dashboard did not become healthy and was stopped\n' >&2
    printf 'Disable the remaining Funnel mapping with: tailscale funnel --https=443 off\n' >&2
    exit 1
  fi

  printf 'Dashboard restarted; the old passphrase and existing dashboard logins are invalid.\n'
else
  printf 'The dashboard is not active; the passphrase will apply on its next start.\n'
fi
