#!/usr/bin/env bash
set -u

failures=0
environment_file="${AOE_DASHBOARD_ENV_FILE:-${XDG_CONFIG_HOME:-${HOME}/.config}/aoe-dashboard/serve.env}"
aoe_state_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/agent-of-empires"
aoe_config="${AOE_CONFIG_FILE:-${aoe_state_dir}/config.toml}"
codex_config="${CODEX_CONFIG_FILE:-${HOME}/.codex/config.toml}"
codex_home="$(dirname -- "$codex_config")"

check() {
  label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'ok   %s\n' "$label"
  else
    printf 'fail %s\n' "$label"
    failures=$((failures + 1))
  fi
}

check_value() {
  label="$1"
  expected="$2"
  shift 2
  actual="$("$@" 2>/dev/null)"
  if [ "$actual" = "$expected" ]; then
    printf 'ok   %s\n' "$label"
  else
    printf 'fail %s (expected %s, got %s)\n' "$label" "$expected" "${actual:-<empty>}"
    failures=$((failures + 1))
  fi
}

check_loopback_8080() {
  ss -H -ltn | awk '
    $4 ~ /127[.]0[.]0[.]1:8080$/ { loopback = 1; next }
    $4 ~ /:8080$/ { public = 1 }
    END { exit !(loopback && !public) }
  '
}

check_ssh_agent_environment() {
  expected="SSH_AUTH_SOCK=/run/user/$(id -u)/ssh-agent"
  systemctl --user show -p Environment --value aoe-dashboard.service \
    | tr ' ' '\n' \
    | grep -Fxq "$expected"
}

check_toml_value() {
  config_file="$1"
  key_path="$2"
  value_type="$3"
  expected="$4"

  python3 - "$config_file" "$key_path" "$value_type" "$expected" <<'PY'
import pathlib
import sys
import tomllib

config_path = pathlib.Path(sys.argv[1])
keys = sys.argv[2].split(".")
value_type = sys.argv[3]
expected_text = sys.argv[4]

value = tomllib.loads(config_path.read_text())
for key in keys:
    value = value[key]

if value_type == "bool":
    expected = expected_text == "true"
elif value_type == "integer":
    expected = int(expected_text)
elif value_type == "string":
    expected = expected_text
else:
    raise ValueError(f"unsupported expected value type: {value_type}")

raise SystemExit(0 if value == expected else 1)
PY
}

check_toml_path_absent() {
  config_file="$1"
  key_path="$2"

  python3 - "$config_file" "$key_path" <<'PY'
import pathlib
import sys
import tomllib

value = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
for key in sys.argv[2].split("."):
    if not isinstance(value, dict) or key not in value:
        raise SystemExit(0)
    value = value[key]
raise SystemExit(1)
PY
}

check_codex_mcp() {
  profile="$1"
  server_name="$2"
  expected_enabled="$3"
  expected_url="${4:-}"

  if [ "$profile" = "default" ]; then
    mcp_json="$(codex mcp list --json)"
  else
    mcp_json="$(codex --profile "$profile" mcp list --json)"
  fi
  printf '%s\n' "$mcp_json" | python3 -c '
import json
import sys

server_name, expected_enabled, expected_url = sys.argv[1:]
servers = {server["name"]: server for server in json.load(sys.stdin)}
server = servers[server_name]
enabled = server.get("enabled") is True
if enabled != (expected_enabled == "true"):
    raise SystemExit(1)
if expected_url and server.get("transport", {}).get("url") != expected_url:
    raise SystemExit(1)
' "$server_name" "$expected_enabled" "$expected_url"
}

check_codex_mcp_absent() {
  profile="$1"
  server_name="$2"

  if [ "$profile" = "default" ]; then
    mcp_json="$(codex mcp list --json)"
  else
    mcp_json="$(codex --profile "$profile" mcp list --json)"
  fi
  printf '%s\n' "$mcp_json" | python3 -c '
import json
import sys

server_name = sys.argv[1]
servers = {server["name"] for server in json.load(sys.stdin)}
raise SystemExit(0 if server_name not in servers else 1)
' "$server_name"
}

check_codex_plugin() {
  profile="$1"
  plugin_id="$2"
  expected_enabled="$3"

  if [ "$profile" = "default" ]; then
    plugin_json="$(codex plugin list --json)"
  else
    plugin_json="$(codex --profile "$profile" plugin list --json)"
  fi
  printf '%s\n' "$plugin_json" | python3 -c '
import json
import sys

plugin_id, expected_enabled = sys.argv[1:]
plugins = {
    plugin["pluginId"]: plugin
    for plugin in json.load(sys.stdin).get("installed", [])
}
plugin = plugins[plugin_id]
if plugin.get("installed") is not True:
    raise SystemExit(1)
enabled = plugin.get("enabled") is True
raise SystemExit(0 if enabled == (expected_enabled == "true") else 1)
' "$plugin_id" "$expected_enabled"
}

check_json_value() {
  config_file="$1"
  key_path="$2"
  expected="$3"

  python3 - "$config_file" "$key_path" "$expected" <<'PY'
import json
import pathlib
import sys

value = json.loads(pathlib.Path(sys.argv[1]).read_text())
for key in sys.argv[2].split("."):
    value = value[key]
raise SystemExit(0 if value == sys.argv[3] else 1)
PY
}

check_legacy_sentry_skill_removed() {
  test ! -e "${HOME}/.agents/skills/sentry-fix-issues" || return 1
  python3 - "${HOME}/.agents/.skill-lock.json" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
if not path.exists():
    raise SystemExit(0)
data = json.loads(path.read_text())
raise SystemExit(0 if "sentry-fix-issues" not in data.get("skills", {}) else 1)
PY
}

check "tailscale status" tailscale status
check "Tailscale Funnel status" tailscale funnel status
check "tmux version" tmux -V
check "Git version" git --version
check "Codex version" codex --version
check "Codex login" codex login status
check "AoE version" aoe --version
check "Codex MCP OAuth callback port is fixed" check_toml_value \
  "$codex_config" "mcp_oauth_callback_port" integer 1455
check "Codex Sentry plugin is disabled by default" check_codex_plugin \
  default sentry@sentry-plugin-marketplace false
check "Codex Sentry MCP is absent by default" check_codex_mcp_absent \
  default sentry
check "Codex OWN MCP is disabled by default" check_codex_mcp \
  default own-context false
check "Codex SEO profile exists" test -f "$codex_home/seo.config.toml"
check "Codex OWN profile exists" test -f "$codex_home/own.config.toml"
check "Codex Sentry profile exists" test -f "$codex_home/sentry.config.toml"
check "Codex SEO profile enables Nix native libraries" check_toml_value \
  "$codex_home/seo.config.toml" \
  "shell_environment_policy.set.LD_LIBRARY_PATH" string \
  "/run/current-system/sw/share/nix-ld/lib"
check "Codex OWN profile enables OWN MCP" check_toml_value \
  "$codex_home/own.config.toml" "mcp_servers.own-context.enabled" bool true
check "Codex Sentry profile enables the official plugin" check_codex_plugin \
  sentry sentry@sentry-plugin-marketplace true
check "Codex Sentry profile enables the plugin MCP" check_codex_mcp \
  sentry sentry true "https://mcp.sentry.dev/mcp?utm_source=plugin"
check "Deprecated Sentry skill is removed" check_legacy_sentry_skill_removed
check "AoE uses tmux for new session attachment" check_toml_value \
  "$aoe_config" "session.new_session_attach_mode" string tmux
check "AoE keeps worktrees disabled by default" check_toml_value \
  "$aoe_config" "worktree.enabled" bool false
check "AoE legacy codex-sentry command is absent" check_toml_path_absent \
  "$aoe_config" "session.custom_agents.codex-sentry"
check "AoE legacy codex-sentry detector is absent" check_toml_path_absent \
  "$aoe_config" "session.agent_detect_as.codex-sentry"
check "AoE SEO profile selects Codex SEO" check_toml_value \
  "$aoe_state_dir/profiles/seo/config.toml" \
  "session.agent_command_override.codex" string "codex --profile seo"
check "AoE OWN profile selects Codex OWN" check_toml_value \
  "$aoe_state_dir/profiles/own/config.toml" \
  "session.agent_command_override.codex" string "codex --profile own"
check "AoE Sentry profile selects Codex Sentry" check_toml_value \
  "$aoe_state_dir/profiles/sentry/config.toml" \
  "session.agent_command_override.codex" string "codex --profile sentry"
check "AoE Sentry ACP profile supplies the official MCP" check_json_value \
  "$aoe_state_dir/profiles/sentry/mcp.json" \
  "mcpServers.sentry.url" "https://mcp.sentry.dev/mcp?utm_source=plugin"
check "AoE dashboard service is active" systemctl --user is-active aoe-dashboard.service
check "AoE serve daemon reports healthy" aoe serve --status
check "AoE dashboard URL exists (output suppressed)" aoe url
check "AoE listens only on IPv4 loopback port 8080" check_loopback_8080
check "cloudflared is absent from PATH" bash -c '! command -v cloudflared >/dev/null 2>&1'
check "dashboard environment file exists" test -f "$environment_file"
check_value "dashboard environment file mode is 0600" "600" stat -c %a "$environment_file"
check "AoE runtime passphrase file exists" test -f "$aoe_state_dir/serve.passphrase"
check_value "AoE runtime passphrase file mode is 0600" "600" stat -c %a "$aoe_state_dir/serve.passphrase"
check_value "dashboard service uses Restart=on-failure" "on-failure" systemctl --user show -p Restart --value aoe-dashboard.service
check_value "dashboard stop preserves tmux processes" "process" systemctl --user show -p KillMode --value aoe-dashboard.service
check "dashboard agents use the Home Manager SSH agent" check_ssh_agent_environment
check_value "user lingering is enabled" "yes" loginctl show-user "$USER" -p Linger --value

if [ "$failures" -ne 0 ]; then
  printf '\n%s AoE checks failed.\n' "$failures" >&2
  exit 1
fi
