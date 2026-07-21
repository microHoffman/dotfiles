#!/usr/bin/env bash
set -u

failures=0
environment_file="${AOE_DASHBOARD_ENV_FILE:-${XDG_CONFIG_HOME:-${HOME}/.config}/aoe-dashboard/serve.env}"
aoe_state_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/agent-of-empires"
aoe_config="${AOE_CONFIG_FILE:-${aoe_state_dir}/config.toml}"
codex_config="${CODEX_CONFIG_FILE:-${HOME}/.codex/config.toml}"

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
elif value_type == "string":
    expected = expected_text
else:
    raise ValueError(f"unsupported expected value type: {value_type}")

raise SystemExit(0 if value == expected else 1)
PY
}

check "tailscale status" tailscale status
check "Tailscale Funnel status" tailscale funnel status
check "tmux version" tmux -V
check "Git version" git --version
check "Codex version" codex --version
check "Codex login" codex login status
check "AoE version" aoe --version
check "Codex Sentry MCP is disabled by default" check_toml_value \
  "$codex_config" "mcp_servers.sentry.enabled" bool false
check "AoE uses tmux for new session attachment" check_toml_value \
  "$aoe_config" "session.new_session_attach_mode" string tmux
check "AoE exposes the codex-sentry agent" check_toml_value \
  "$aoe_config" "session.custom_agents.codex-sentry" string \
  "codex --config mcp_servers.sentry.enabled=true"
check "AoE detects codex-sentry as Codex" check_toml_value \
  "$aoe_config" "session.agent_detect_as.codex-sentry" string codex
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
