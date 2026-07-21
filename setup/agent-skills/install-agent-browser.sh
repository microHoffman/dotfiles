#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${script_dir}/_lib.sh"

need_cmd npm
need_cmd node

node_major="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$node_major" -lt 24 ]; then
  if ! command -v mise >/dev/null 2>&1; then
    printf 'install-agent-browser: agent-browser requires Node 24 or newer\n' >&2
    exit 1
  fi
  mise use --global node@24
  node_major="$(node -p 'process.versions.node.split(".")[0]')"
fi
if [ "$node_major" -lt 24 ]; then
  printf 'install-agent-browser: failed to activate Node 24 or newer\n' >&2
  exit 1
fi

npm install --global agent-browser@latest
agent-browser install
install_global_skill https://github.com/vercel-labs/agent-browser agent-browser
