#!/usr/bin/env bash
set -euo pipefail

environment_file="${AOE_DASHBOARD_ENV_FILE:-${XDG_CONFIG_HOME:-${HOME}/.config}/aoe-dashboard/serve.env}"
environment_dir="$(dirname -- "$environment_file")"

if [ ! -t 0 ]; then
  printf 'set-passphrase: an interactive terminal is required\n' >&2
  exit 1
fi

if [ -e "$environment_file" ]; then
  printf 'A dashboard passphrase already exists. Rotating it signs out connected devices.\n'
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
printf 'Restart aoe-dashboard only after its Tailscale Funnel approval gate is complete.\n'
