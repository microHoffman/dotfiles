#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
depoto_client=""
own_mcp=""
pwn_protocol=""

usage() {
  printf 'Usage: %s [--depoto-client PATH] [--own-mcp PATH] [--pwn-protocol PATH]\n' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --depoto-client)
      depoto_client="${2:-}"
      shift 2
      ;;
    --own-mcp)
      own_mcp="${2:-}"
      shift 2
      ;;
    --pwn-protocol)
      pwn_protocol="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'install-all: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

"${script_dir}/install-all-global.sh"

if [ -n "$depoto_client" ]; then
  "${script_dir}/install-tanstack-query-angular.sh" "$depoto_client"
else
  printf '\nSkipped Depoto Client skill. Later run:\n  %s /path/to/depoto-client\n' \
    "${script_dir}/install-tanstack-query-angular.sh"
fi

if [ -n "$own_mcp" ]; then
  "${script_dir}/install-mcp-builder.sh" "$own_mcp"
else
  printf '\nSkipped OWN MCP skill. Later run:\n  %s /path/to/own_mcp\n' \
    "${script_dir}/install-mcp-builder.sh"
fi

if [ -n "$pwn_protocol" ]; then
  "${script_dir}/install-pwn-protocol-skills.sh" "$pwn_protocol"
else
  printf '\nSkipped PWN Protocol skills. Later run:\n  %s /path/to/pwn_protocol\n' \
    "${script_dir}/install-pwn-protocol-skills.sh"
fi
