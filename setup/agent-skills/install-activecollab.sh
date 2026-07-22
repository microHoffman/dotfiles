#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${script_dir}/_lib.sh"

need_cmd mise
need_cmd npx

activecollab_cli_tool="github:microHoffman/activecollab-cli"
activecollab_cli_requested_version="${ACTIVECOLLAB_CLI_VERSION:-latest}"
activecollab_cli_minimum_version="0.3.0"
mise_config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
activecollab_cli_config="${mise_config_home}/mise/conf.d/activecollab-cli.toml"

mkdir -p "$(dirname -- "$activecollab_cli_config")"
if [ "$activecollab_cli_requested_version" = "latest" ]; then
  activecollab_cli_version="$(
    MISE_MINIMUM_RELEASE_AGE=0d mise latest "$activecollab_cli_tool"
  )"
else
  activecollab_cli_version="$activecollab_cli_requested_version"
fi

mise use --path "$activecollab_cli_config" \
  "${activecollab_cli_tool}@${activecollab_cli_version}"

version_output="$(
  mise exec "${activecollab_cli_tool}@${activecollab_cli_version}" -- \
    activecollab version --json
)"
if [[ ! "$version_output" =~ \"version\":\"([^\"]+)\" ]]; then
  printf 'install-activecollab: could not read the installed CLI version\n' >&2
  exit 1
fi
installed_version="${BASH_REMATCH[1]}"
oldest_version="$(
  printf '%s\n%s\n' "$activecollab_cli_minimum_version" "$installed_version" |
    sort -V |
    head -n 1
)"
if [[ "$oldest_version" != "$activecollab_cli_minimum_version" ]]; then
  printf 'install-activecollab: CLI version %s is older than required version %s\n' \
    "$installed_version" "$activecollab_cli_minimum_version" >&2
  exit 1
fi

install_global_skill https://github.com/microHoffman/agent-skills activecollab

printf 'Installed activecollab CLI %s and the activecollab agent skill.\n' "$installed_version"
printf 'Log in with: activecollab auth login --url https://activecollab.example.com/api/v1\n'
