#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${script_dir}/_lib.sh"

need_cmd codex
need_cmd npx
need_cmd python3
need_cmd reconcile-managed-agent-configs

marketplace_name="sentry-plugin-marketplace"
marketplace_source="getsentry/plugin-codex"
plugin_id="sentry@${marketplace_name}"

marketplace_state="$({ codex plugin marketplace list --json; } | python3 -c '
import json
import sys

name = sys.argv[1]
expected = sys.argv[2]
entries = [
    entry
    for entry in json.load(sys.stdin).get("marketplaces", [])
    if entry.get("name") == name
]
if not entries:
    print("absent")
    raise SystemExit(0)
if len(entries) != 1:
    print(f"install-sentry-plugin: duplicate marketplace entries: {name}", file=sys.stderr)
    raise SystemExit(1)

source = entries[0].get("marketplaceSource") or {}
source_type = source.get("sourceType")
source_value = source.get("source", "")
normalized = source_value.removesuffix(".git").rstrip("/")
normalized = normalized.removeprefix("https://github.com/")
normalized = normalized.removeprefix("http://github.com/")
normalized = normalized.removeprefix("ssh://git@github.com/")
normalized = normalized.removeprefix("git@github.com:")
if source_type != "git" or normalized != expected:
    display_type = source_type or "unknown"
    display_value = source_value or "unknown"
    print(
        "install-sentry-plugin: existing marketplace has an unexpected source: "
        f"{name} ({display_type}: {display_value})",
        file=sys.stderr,
    )
    raise SystemExit(1)
print("present")
' "$marketplace_name" "$marketplace_source")"

reconcile_needed=1
restore_managed_config() {
  if [ "$reconcile_needed" -eq 1 ]; then
    if ! reconcile-managed-agent-configs; then
      printf 'install-sentry-plugin: failed to restore managed Codex profile state\n' >&2
    fi
  fi
}
trap restore_managed_config EXIT

if [ "$marketplace_state" = "absent" ]; then
  codex plugin marketplace add "$marketplace_source"
else
  codex plugin marketplace upgrade "$marketplace_name"
fi

codex plugin add "$plugin_id"
reconcile-managed-agent-configs
reconcile_needed=0
trap - EXIT

plugin_is_installed() {
  local requested_plugin_id="$1"
  codex plugin list --json | python3 -c '
import json
import sys

requested = sys.argv[1]
installed = json.load(sys.stdin).get("installed", [])
raise SystemExit(
    0
    if any(
        plugin.get("pluginId") == requested
        and plugin.get("installed") is True
        for plugin in installed
    )
    else 1
)
' "$requested_plugin_id"
}

if ! plugin_is_installed "$plugin_id"; then
  printf 'install-sentry-plugin: Codex did not report the plugin as installed: %s\n' \
    "$plugin_id" >&2
  exit 1
fi

if plugin_is_installed "sentry@openai-curated"; then
  codex plugin remove "sentry@openai-curated"
fi

legacy_lock="${HOME}/.agents/.skill-lock.json"
legacy_dir="${HOME}/.agents/skills/sentry-fix-issues"
legacy_state="$(python3 - "$legacy_lock" "$legacy_dir" <<'PY'
import json
import pathlib
import sys

lock_path = pathlib.Path(sys.argv[1])
skill_path = pathlib.Path(sys.argv[2])
if not lock_path.exists():
    if skill_path.exists() or skill_path.is_symlink():
        print(
            "install-sentry-plugin: refusing to remove an unlocked legacy skill: "
            f"{skill_path}",
            file=sys.stderr,
        )
        raise SystemExit(1)
    print("absent")
    raise SystemExit(0)

try:
    lock = json.loads(lock_path.read_text())
except (OSError, json.JSONDecodeError) as error:
    print(f"install-sentry-plugin: could not read {lock_path}: {error}", file=sys.stderr)
    raise SystemExit(1)

entry = lock.get("skills", {}).get("sentry-fix-issues")
if entry is None:
    if skill_path.exists() or skill_path.is_symlink():
        print(
            "install-sentry-plugin: refusing to remove an untracked legacy skill: "
            f"{skill_path}",
            file=sys.stderr,
        )
        raise SystemExit(1)
    print("absent")
    raise SystemExit(0)

if (
    entry.get("source") != "getsentry/sentry-agent-skills"
    or entry.get("skillPath") != "skills/sentry-fix-issues/SKILL.md"
):
    print(
        "install-sentry-plugin: refusing to remove a legacy skill with unexpected ownership",
        file=sys.stderr,
    )
    raise SystemExit(1)
print("managed")
PY
)"

if [ "$legacy_state" = "managed" ]; then
  npx -y skills@latest remove \
    --global \
    --agent '*' \
    --yes \
    sentry-fix-issues
fi

python3 - "$legacy_lock" "$legacy_dir" <<'PY'
import json
import pathlib
import sys

lock_path = pathlib.Path(sys.argv[1])
skill_path = pathlib.Path(sys.argv[2])
if skill_path.exists() or skill_path.is_symlink():
    raise SystemExit(f"legacy Sentry skill remains installed: {skill_path}")
if lock_path.exists():
    lock = json.loads(lock_path.read_text())
    if "sentry-fix-issues" in lock.get("skills", {}):
        raise SystemExit(f"legacy Sentry skill remains in lock file: {lock_path}")
PY

printf 'Installed official Sentry Codex plugin: %s\n' "$plugin_id"
