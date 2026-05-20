#!/usr/bin/env bash
set -euo pipefail

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'install-create-pull-request: missing required command: %s\n' "$1" >&2
    exit 1
  }
}

need_cmd npx

npx skills add https://github.com/microHoffman/agent-skills --skill create-pull-request --agent '*' --global --yes
