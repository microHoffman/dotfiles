#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${script_dir}/_lib.sh"

need_cmd node

agent_browser_prefix="${AGENT_BROWSER_NPM_PREFIX:-${HOME}/.local}"
node_major="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$node_major" -lt 24 ]; then
  need_cmd mise
  mise install node@24
  node_major="$(
    mise exec node@24 -- node -p 'process.versions.node.split(".")[0]'
  )"
  if [ "$node_major" -lt 24 ]; then
    printf 'install-agent-browser: failed to install Node 24 or newer\n' >&2
    exit 1
  fi
  npm_command=(mise exec node@24 -- npm)
else
  need_cmd npm
  npm_command=(npm)
fi

"${npm_command[@]}" install --global --prefix "$agent_browser_prefix" agent-browser@latest
agent_browser_bin="${agent_browser_prefix}/bin/agent-browser"
if [ ! -x "$agent_browser_bin" ]; then
  printf 'install-agent-browser: expected executable was not installed: %s\n' \
    "$agent_browser_bin" >&2
  exit 1
fi
"$agent_browser_bin" install
install_global_skill https://github.com/vercel-labs/agent-browser agent-browser
