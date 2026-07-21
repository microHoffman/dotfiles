#!/usr/bin/env bash
set -euo pipefail

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'install-activecollab-cli: missing required command: %s\n' "$1" >&2
    exit 1
  }
}

need_cmd mise

activecollab_cli_version="${ACTIVECOLLAB_CLI_VERSION:-0.3.0}"
mise use --global "github:microHoffman/activecollab-cli@${activecollab_cli_version}"
activecollab version
