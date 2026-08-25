# Remote Codex and Agent of Empires setup

This directory contains the portable, non-secret part of the personal remote
Codex/AoE setup. NixOS owns system packages and the user service; these scripts
handle user-installed tools and mutable application configuration.

## Install only missing user tools

The Codex and AoE installers download each official installer to a temporary
directory, show its SHA-256 digest, open it in `$PAGER`, and require an exact
confirmation before execution. The delegated `codex-acp` installer uses npm
with an explicit `~/.local` prefix. Existing installations are preserved.

```bash
setup/aoe-remote/install-user-tools.sh codex aoe codex-acp
```

`codex-acp` requires Node.js 20 or newer. Update it intentionally, outside
Home Manager activation, with:

```bash
setup/codex-acp/install.sh --update
```

Authenticate separately using supported interactive flows:

```bash
codex login --device-auth
codex login status
```

Tailscale authentication remains part of the privileged host runbook.

## Seed safe application defaults

Run this before the first Codex or AoE launch on a fresh host:

```bash
setup/aoe-remote/install-config.sh
```

The script installs owner-only baseline files only when the corresponding
config does not exist. It never overwrites an existing config. Machine-generated
Codex trust entries, hook hashes, tokens, session state, and AoE UI state do not
belong in this repository.

On the NixOS `remote-dev` host, Home Manager also treats every value in
`codex-config.toml` and `aoe-config.toml` as an authoritative overlay. Every
NixOS or Home Manager activation deep-merges those values into the live
application configs. Tables are merged recursively, repository scalars and
arrays win, and keys that exist only in the live files are preserved. Removing
a key from a repository template does not delete the live key; intentional
removals require a separate migration. The merge uses application locks and
atomic owner-only writes.

The Codex baseline uses `workspace-write`, interactive `on-request` approvals,
and `approvals_reviewer = "auto_review"`. Auto-review changes who reviews an
eligible escalation; it does not disable the sandbox or grant full host access.

The AoE baseline keeps terminal/tmux sessions as the default, makes Codex the
default tool, keeps worktrees opt-in for each new session, preserves explicit
conversation resume, and keeps YOLO disabled. It offers ACP structured view as
an explicit session choice with AoE 1.13.1 or newer. Dashboard-managed ACP
adapter installation remains disabled; install or update adapters through the
reviewed portable installer.

The default Codex configuration keeps the official Sentry plugin disabled.
The `sentry` profile enables the complete plugin, including its upstream skills
and hosted MCP configuration. Install or update it with the global installer.
Codex 0.145.0 does not apply profile overlays in `codex mcp` management
subcommands, so authenticate the plugin MCP with a one-off URL override:

```bash
setup/agent-skills/install-all-global.sh
codex -c 'mcp_servers.sentry.url="https://mcp.sentry.dev/mcp?utm_source=plugin"' mcp login sentry
```

The override is used only to make the server visible to the login subcommand;
normal Sentry sessions still use `codex --profile sentry` and the MCP bundled by
the official plugin.

The installer uses Sentry's Codex marketplace distribution and preserves the
invocation policy shipped with each skill. The deprecated standalone
`sentry-fix-issues` installation and its custom metadata are removed during the
migration.

The base configuration does not declare Figma, Notion, or `own-context`. The
`own` Codex profile contains their complete configuration, while the matching
AoE profile supplies all three transports to ACP sessions through its local
`mcp.json`. Figma and Notion use `writes` approval mode in the Codex profile.
Because AoE's transport file cannot carry that Codex-specific policy, global
guidance applies matching safeguards only when their tools are available:
Codex must describe each proposed write, ask for explicit confirmation, and
wait for a later user message. The original request does not count as that
confirmation. Codex still uses the configured automatic reviewer after
confirmation; the text-confirmation instruction is a behavioral safeguard, not
a separate enforcement boundary.

Authenticate Figma once on each machine. Codex MCP management commands do not
load named profile overlays, so the one-off override supplies the same server
name and URL used by both OWN modes:

```bash
codex -c 'mcp_servers.figma.url="https://mcp.figma.com/mcp"' \
  mcp login figma
```

Figma requires interactive user OAuth; no Figma token belongs in this
repository. Complete the printed authorization URL in a browser and keep the
OAuth credentials machine-local. On a headless host, use the callback-port SSH
tunnel described below for Notion; the same tunnel and fresh-port recovery
procedure apply to Figma.

Authenticate Notion once on each machine. Codex MCP management commands do not
load named profile overlays, so the one-off override supplies the same server
name and URL used by both OWN modes:

```bash
codex -c 'mcp_servers.notion.url="https://mcp.notion.com/mcp"' \
  mcp login notion
```

Notion requires interactive user OAuth; no Notion API token belongs in this
repository. On a headless `remote-dev` session, first forward the fixed callback
port from the workstation where the authorization page will open:

```bash
ssh -N -L 1455:127.0.0.1:1455 microhoffman@remote-dev
```

Then run the login command on `remote-dev`, open the printed URL locally, and
authorize the intended Notion workspace. The OAuth credentials remain
machine-local.

If login exits with `Authorization state not found`, close any old Figma,
Notion, or `127.0.0.1:1455` browser tabs and stop the old tunnel. On the
workstation, keep a fresh one-off callback port forwarded:

```bash
ssh -N -L 1456:127.0.0.1:1456 microhoffman@remote-dev
```

In a separate `remote-dev` shell, use the same port for login:

```bash
codex -c 'mcp_oauth_callback_port=1456' \
  -c 'mcp_servers.notion.url="https://mcp.notion.com/mcp"' \
  mcp login notion
```

For Figma, use the same callback override with
`mcp_servers.figma.url="https://mcp.figma.com/mcp"` and `mcp login figma`.
Open only the newly printed authorization URL. A callback from an older login
has a different OAuth state and aborts the current listener.

Existing `own-context` credentials are also reused by server name and URL. If
they need to be recreated, supply its complete OAuth metadata to the management
command:

```bash
codex \
  -c 'mcp_servers.own-context.url="https://mcp.own.casa/mcp"' \
  -c 'mcp_servers.own-context.scopes=["openid","offline_access","context.read","context.validate","grants.read","grants.write"]' \
  -c 'mcp_servers.own-context.oauth.client_id="C6yemhZP2rhCPMZIuNTHKnd2hu6cyMXB"' \
  mcp login own-context
```

Three optional profiles are installed:

- `codex --profile seo` enables the local Codex SEO suite, except integrations
  that require separately configured DataForSEO, Firecrawl, Google, or Gemini
  credentials.
- `codex --profile own` enables the hosted `own-context`, Figma, and Notion MCP
  servers.
- `codex --profile sentry` enables Sentry's official Codex plugin, all of its
  bundled skills, and its hosted MCP server.

AoE profiles named `seo`, `own`, and `sentry` launch Codex with those profile
flags in tmux mode. Use `aoe -p seo`, `aoe -p own`, or `aoe -p sentry`; each AoE
profile has its own session workspace. The OWN and Sentry AoE profiles also
supply their hosted MCP transports through profile-local `mcp.json` files for
ACP sessions. ACP does not activate Codex named-profile skills or plugins.

Verify the ACP runtime, then create an explicit structured OWN session with:

```bash
aoe acp doctor --json
aoe add -p own --structured-view --tool codex --launch
```

The new-session UI exposes the same structured-view choice. Omitting it keeps
the normal tmux workflow.

On the NixOS `remote-dev` host, Home Manager installs
`reconcile-managed-agent-configs`. Activation and the Sentry plugin installer
both use this command so Codex's native plugin installation cannot leave the
plugin enabled in the default profile. The reconciler removes known legacy
values only when they still exactly match the old dotfiles-managed values.
Home Manager configures the dashboard's Node runtime but never runs npm or
changes the installed `codex-acp` version during activation.

## Install skills and documentation access

Install the complete global skill/tool set:

```bash
setup/agent-skills/install-all-global.sh
```

Or install global and known repository-scoped skills together:

```bash
setup/agent-skills/install-all.sh \
  --depoto-client ~/tomatom/client \
  --own-mcp ~/own/own_mcp \
  --pwn-protocol ~/pwn/pwn_protocol
```

Repository arguments are optional and explicit. No Trail of Bits skill is
installed in Proof of Presence. Each skill also has an individual installer in
`setup/agent-skills/` for selective installs and updates.

Initialize GitHits after GitHub CLI authentication:

```bash
setup/githits/init.sh
```

GitHits owns its interactive authentication and generated machine-local
integration. Dotfiles does not duplicate its MCP or guidance block.

## Store or rotate the dashboard passphrase

Generate a unique value in a password manager, then paste it twice into the
hidden prompt:

```bash
setup/aoe-remote/set-passphrase.sh
```

It writes `~/.config/aoe-dashboard/serve.env` with mode `0600` under an
owner-only directory. The value is never passed as a command-line argument.
If the dashboard is active, the script restarts it and verifies the restart so
rotation takes effect immediately and signs out connected dashboard devices. It
does not start an inactive dashboard. If the restarted dashboard does not become
healthy, the script stops it and prints the command that removes the remaining
Funnel mapping.

Do not create this file until the Tailscale Funnel exposure has been reviewed
and approved. The Nix service remains disabled by default in
`nix/shared/vars.nix`.

See [`docs/remote-codex-aoe.md`](../../docs/remote-codex-aoe.md) for the full
approval sequence, Android setup, operations, and recovery runbook.
