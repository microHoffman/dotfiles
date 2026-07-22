#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s /path/to/reconcile-agent-config\n' "${0##*/}" >&2
  exit 2
fi

reconciler="$1"
temporary_dir="$(mktemp -d)"
cleanup() {
  rm -rf -- "$temporary_dir"
}
trap cleanup EXIT

source_file="${temporary_dir}/source.toml"
target_file="${temporary_dir}/config/config.toml"
lock_file="${temporary_dir}/config/config.toml.lock"

mkdir -p -- "$(dirname -- "$target_file")"

cat >"$source_file" <<'TOML'
name = "managed"
environment = ["TERM", "COLORTERM"]

[session]
new_session_attach_mode = "tmux"

[worktree]
enabled = false

[mcp_servers.own-context]
url = "https://mcp.own.casa/mcp"
enabled = false
TOML

cat >"$target_file" <<'TOML'
# Preserve this application-generated comment.
name = "local"
environment = ["TERM"]
generated = "keep"

[session]
new_session_attach_mode = "live_send"
unread_indicator = true

[worktree]
enabled = true

[mcp_servers.sentry]
url = "https://mcp.sentry.dev/mcp?skills=inspect"
enabled = true

[mcp_servers.custom]
url = "https://mcp.example.com/mcp"
enabled = true

[session.custom_agents]
codex-sentry = "codex --config mcp_servers.sentry.enabled=true"
custom = "custom-agent"

[session.agent_detect_as]
codex-sentry = "codex"

[hooks.state]
trusted = "keep"
TOML
chmod 0640 "$target_file"

delete_legacy_values=(
  --delete-if-equals mcp_servers.sentry \
    '{ url = "https://mcp.sentry.dev/mcp?skills=inspect", enabled = true }'
  --delete-if-equals session.custom_agents.codex-sentry \
    '"codex --config mcp_servers.sentry.enabled=true"'
  --delete-if-equals session.agent_detect_as.codex-sentry '"codex"'
)

"$reconciler" \
  --source "$source_file" \
  --target "$target_file" \
  --lock "$lock_file" \
  "${delete_legacy_values[@]}"

python3 - "$target_file" <<'PY'
import pathlib
import sys
import tomllib

path = pathlib.Path(sys.argv[1])
data = tomllib.loads(path.read_text())
assert data["name"] == "managed"
assert data["environment"] == ["TERM", "COLORTERM"]
assert data["generated"] == "keep"
assert data["session"]["new_session_attach_mode"] == "tmux"
assert data["session"]["unread_indicator"] is True
assert data["worktree"]["enabled"] is False
assert "sentry" not in data["mcp_servers"]
assert data["mcp_servers"]["custom"]["enabled"] is True
assert data["mcp_servers"]["own-context"]["enabled"] is False
assert "codex-sentry" not in data["session"]["custom_agents"]
assert data["session"]["custom_agents"]["custom"] == "custom-agent"
assert "agent_detect_as" not in data["session"]
assert data["hooks"]["state"]["trusted"] == "keep"
PY

grep -Fq '# Preserve this application-generated comment.' "$target_file"
test "$(stat -c %a "$target_file")" = "640"

inode_before="$(stat -c %i "$target_file")"
"$reconciler" \
  --source "$source_file" \
  --target "$target_file" \
  --lock "$lock_file" \
  "${delete_legacy_values[@]}"
test "$(stat -c %i "$target_file")" = "$inode_before"

minimal_source="${temporary_dir}/minimal.toml"
printf 'name = "managed"\n' >"$minimal_source"

modified_target="${temporary_dir}/modified.toml"
modified_lock="${temporary_dir}/modified.lock"
cat >"$modified_target" <<'TOML'
[mcp_servers.sentry]
url = "https://self-hosted.example.com/mcp"
enabled = true

[session.custom_agents]
codex-sentry = "custom-codex-sentry"

[session.agent_detect_as]
codex-sentry = "custom-detector"
TOML
"$reconciler" \
  --source "$minimal_source" \
  --target "$modified_target" \
  --lock "$modified_lock" \
  "${delete_legacy_values[@]}"
python3 - "$modified_target" <<'PY'
import pathlib
import sys
import tomllib

data = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
assert data["mcp_servers"]["sentry"]["url"] == "https://self-hosted.example.com/mcp"
assert data["session"]["custom_agents"]["codex-sentry"] == "custom-codex-sentry"
assert data["session"]["agent_detect_as"]["codex-sentry"] == "custom-detector"
PY

"$reconciler" --source "$minimal_source" --target "$target_file" --lock "$lock_file"
python3 - "$target_file" <<'PY'
import pathlib
import sys
import tomllib

data = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
assert "mcp_servers" in data
assert data["generated"] == "keep"
PY

missing_target="${temporary_dir}/missing/config.toml"
missing_lock="${temporary_dir}/missing/.config.lock"
"$reconciler" --source "$source_file" --target "$missing_target" --lock "$missing_lock"
test "$(stat -c %a "$missing_target")" = "600"

malformed_target="${temporary_dir}/malformed.toml"
malformed_lock="${temporary_dir}/malformed.lock"
printf '[broken\n' >"$malformed_target"
malformed_hash="$(sha256sum "$malformed_target")"
if "$reconciler" --source "$source_file" --target "$malformed_target" --lock "$malformed_lock"; then
  printf 'expected malformed target reconciliation to fail\n' >&2
  exit 1
fi
test "$(sha256sum "$malformed_target")" = "$malformed_hash"

malformed_source="${temporary_dir}/malformed-source.toml"
printf '[broken\n' >"$malformed_source"
if "$reconciler" --source "$malformed_source" --target "$target_file" --lock "$lock_file"; then
  printf 'expected malformed source reconciliation to fail\n' >&2
  exit 1
fi

symlink_target="${temporary_dir}/symlink.toml"
ln -s "$target_file" "$symlink_target"
if "$reconciler" --source "$source_file" --target "$symlink_target" --lock "${temporary_dir}/symlink.lock"; then
  printf 'expected symlink target reconciliation to fail\n' >&2
  exit 1
fi

flock "$lock_file" -c 'sleep 0.5' &
lock_holder=$!
"$reconciler" --source "$source_file" --target "$target_file" --lock "$lock_file"
wait "$lock_holder"

printf 'reconcile-agent-config tests passed\n'
