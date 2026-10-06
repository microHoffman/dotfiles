#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${script_dir}/_lib.sh"
need_cmd python3
need_cmd npx

# Remove only the known retired upstream skill; archive it for rollback first.
retired_state="$(python3 - "${HOME}/.agents/.skill-lock.json" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
entry = json.loads(path.read_text()).get("skills", {}).get("resolving-merge-conflicts") if path.exists() else None
if entry and entry.get("source") != "mattpocock/skills":
    raise SystemExit("Refusing to remove a merge-conflict skill from another source")
print("managed" if entry else "absent")
PY
)"
if [ "$retired_state" = managed ]; then
  backup_root="${XDG_STATE_HOME:-${HOME}/.local/state}/dotfiles/skill-backups"
  install -d -m 700 "$backup_root"
  backup_dir="$(mktemp -d "${backup_root}/retired-merge-conflicts.XXXXXXXX")"
  cp -a "${HOME}/.agents/skills/resolving-merge-conflicts" "$backup_dir/"
  npx -y skills@latest remove --global --yes resolving-merge-conflicts
  printf 'Archived the retired merge-conflict skill in %s\n' "$backup_dir"
fi

# resolving-merge-conflicts was retired upstream in v1.3.0.
install_global_skills https://github.com/mattpocock/skills \
  diagnosing-bugs code-review codebase-design domain-modeling grilling \
  grill-me grill-with-docs improve-codebase-architecture research handoff teach
