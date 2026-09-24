#!/usr/bin/env bash
set -euo pipefail

configure_only=false
if [ "$#" -eq 1 ] && [ "$1" = --configure-only ]; then
  configure_only=true
elif [ "$#" -ne 0 ]; then
  printf 'Usage: %s [--configure-only]\n' "${0##*/}" >&2
  exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
codex_config="${CODEX_HOME:-${HOME}/.codex}/config.toml"
if command -v reconcile-agent-config >/dev/null 2>&1; then
  reconciler=(reconcile-agent-config)
else
  # Portable installs need Python 3.11+ and tomlkit; Nix supplies the helper.
  reconciler=(python3 "${script_dir}/../aoe-remote/reconcile_config.py")
fi
if ! "$configure_only" && ! command -v codex >/dev/null 2>&1; then
  printf 'init-githits: missing required command: codex\n' >&2
  exit 1
fi

umask 077
temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "$temporary_dir"' EXIT
cat >"${temporary_dir}/githits.toml" <<'TOML'
[mcp_servers.githits]
url = "https://mcp.githits.com"
enabled = true
TOML

if [ -f "$codex_config" ]; then
  backup_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/dotfiles/backups/githits"
  mkdir -p -- "$backup_dir"
  backup_file="$(mktemp "${backup_dir}/config.XXXXXXXX.toml")"
  cp -- "$codex_config" "$backup_file"
  chmod 600 "$backup_file"
  printf 'Backed up Codex config: %s\n' "$backup_file"
fi

"${reconciler[@]}" \
  --source "${temporary_dir}/githits.toml" \
  --target "$codex_config" \
  --lock "${codex_config}.lock" \
  --delete-if-equals mcp_servers.githits.command '"npx"' \
  --delete-if-equals mcp_servers.githits.args '["-y", "githits@latest", "mcp", "start"]'

printf 'Codex now uses hosted GitHits. Existing sessions keep their current connection.\n'
printf 'Existing GitHits skills and CLI credentials have been preserved.\n'
if ! "$configure_only"; then
  printf 'Complete the following OAuth flow using your existing GitHits account.\n'
  codex mcp login githits --no-browser
fi
