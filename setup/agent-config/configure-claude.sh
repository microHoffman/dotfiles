#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 0 ]; then
  printf 'Usage: %s\n' "${0##*/}" >&2
  exit 2
fi
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/agent-profiles/claude"
if command -v reconcile-agent-config >/dev/null 2>&1; then
  reconciler=(reconcile-agent-config)
else
  reconciler=(python3 "${script_dir}/../aoe-remote/reconcile_config.py")
fi
python3 "${script_dir}/render-claude.py" \
  --codex-base "${script_dir}/../aoe-remote/codex-config.toml" \
  --codex-own "${script_dir}/../aoe-remote/own.config.toml" --output "$config_dir"
"${reconciler[@]}" --format json --source "${config_dir}/user-mcp.json" \
  --target "${HOME}/.claude.json" --lock "${HOME}/.claude.json.dotfiles.lock"
"${reconciler[@]}" --format json --source "${script_dir}/claude-settings.json" \
  --target "${HOME}/.claude/settings.json" --lock "${HOME}/.claude/settings.json.lock"
install -d -m 700 "${HOME}/.local/bin"
install -m 755 "${script_dir}/claude-profile" "${HOME}/.local/bin/claude-profile"
if [ ! -e "${HOME}/.claude/CLAUDE.md" ]; then
  ln -s "${script_dir}/AGENTS.md" "${HOME}/.claude/CLAUDE.md"
fi
printf 'Claude presets and common MCP configured. Authentication remains optional.\n'
