#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${script_dir}/_lib.sh"
need_cmd claude
need_cmd python3

install_plugin() {
  local source="$1" marketplace="$2" plugin="$3" state
  state="$(claude plugin marketplace list --json | python3 -c '
import json, sys
name, repo = sys.argv[1:]
entries = [x for x in json.load(sys.stdin) if x.get("name") == name]
if not entries:
    print("absent")
elif len(entries) == 1 and entries[0].get("source") == "github" and entries[0].get("repo") == repo:
    print("present")
else:
    raise SystemExit("Refusing unexpected marketplace source: " + name)
' "$marketplace" "$source")"
  if [ "$state" = absent ]; then
    claude plugin marketplace add "$source"
  else
    claude plugin marketplace update "$marketplace"
  fi
  if claude plugin list --json | python3 -c '
import json, sys
raise SystemExit(0 if any(x.get("id") == sys.argv[1] and x.get("scope") == "user"
                        for x in json.load(sys.stdin)) else 1)
' "${plugin}@${marketplace}"; then
    claude plugin update --scope user "${plugin}@${marketplace}"
  else
    claude plugin install --scope user "${plugin}@${marketplace}"
  fi
  # Presets enable the plugin per session. Ordinary Claude stays lightweight.
  claude plugin disable --scope user "${plugin}@${marketplace}"
}

install_plugin getsentry/plugin-claude sentry-plugin-marketplace sentry
install_plugin AgriciDaniel/claude-seo agricidaniel-claude-seo claude-seo
"${script_dir}/setup-claude-seo.sh"
printf 'Installed native Claude Sentry and SEO plugins; enabled only by their presets.\n'
