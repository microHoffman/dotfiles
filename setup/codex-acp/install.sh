#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [--update]\n' "${0##*/}" >&2
}

update=false
case "$#" in
  0)
    ;;
  1)
    if [ "$1" != "--update" ]; then
      usage
      exit 2
    fi
    update=true
    ;;
  *)
    usage
    exit 2
    ;;
esac

if ! command -v node >/dev/null 2>&1; then
  printf 'codex-acp requires Node.js 20 or newer, but node is not on PATH.\n' >&2
  exit 1
fi

node_version="$(node --version)"
node_major="${node_version#v}"
node_major="${node_major%%.*}"
case "$node_major" in
  '' | *[!0-9]*)
    printf 'Could not parse the Node.js version: %s\n' "$node_version" >&2
    exit 1
    ;;
esac
if [ "$node_major" -lt 20 ]; then
  printf 'codex-acp requires Node.js 20 or newer; found %s.\n' "$node_version" >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  printf 'codex-acp requires npm, but npm is not on PATH.\n' >&2
  exit 1
fi

install_prefix="${HOME}/.local"
codex_acp_bin="${install_prefix}/bin/codex-acp"

if [ "$update" = false ] && [ -x "$codex_acp_bin" ]; then
  printf 'codex-acp is already installed; preserving it:\n'
  "$codex_acp_bin" --version
  exit 0
fi

mkdir -p -- "$install_prefix"
npm install --global --prefix "$install_prefix" \
  '@agentclientprotocol/codex-acp@latest'

if [ ! -x "$codex_acp_bin" ]; then
  printf 'codex-acp installation completed without creating %s.\n' \
    "$codex_acp_bin" >&2
  exit 1
fi

hash -r
"$codex_acp_bin" --version
