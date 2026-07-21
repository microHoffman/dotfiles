#!/usr/bin/env bash
set -euo pipefail

if ! command -v npx >/dev/null 2>&1; then
  printf 'init-githits: missing required command: npx\n' >&2
  exit 1
fi

printf 'GitHits setup is interactive and may open a GitHub sign-in flow.\n'
printf 'Its generated authentication and machine-local configuration are not stored in dotfiles.\n'
npx -y githits@latest init
