#!/usr/bin/env bash
set -euo pipefail

plugin_root="$(claude plugin list --json | python3 -c '
import json, sys
matches = [x for x in json.load(sys.stdin)
           if x.get("id") == "claude-seo@agricidaniel-claude-seo" and x.get("scope") == "user"]
if len(matches) != 1:
    raise SystemExit("Install the Claude SEO plugin first")
print(matches[0]["installPath"])
')"
export CLAUDE_SEO_DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/claude-seo"
if [ -d /run/current-system/sw/share/nix-ld/lib ]; then
  export LD_LIBRARY_PATH="/run/current-system/sw/share/nix-ld/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
fi
launcher="${plugin_root}/scripts/claude-seo"
if "$launcher" doctor --json | python3 -c '
import json, sys
s = json.load(sys.stdin)
raise SystemExit(0 if s.get("ready") and s.get("browser_ready") else 1)
'; then
  printf 'Claude SEO runtime and Chromium are already ready.\n'
else
  "$launcher" setup
fi
"$launcher" doctor --json
