# Remote Codex and Agent of Empires setup

This directory contains the portable, non-secret part of the personal remote
Codex/AoE setup. NixOS owns system packages and the user service; these scripts
handle user-installed tools and mutable application configuration.

## Install only missing user tools

The installer downloads each official installer to a temporary directory,
shows its SHA-256 digest, opens it in `$PAGER`, and requires an exact
confirmation before execution. Existing installations are preserved.

```bash
setup/aoe-remote/install-user-tools.sh codex aoe
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

The AoE baseline keeps terminal/tmux sessions, makes Codex the default tool,
keeps worktrees opt-in for each new session, preserves explicit conversation
resume, and keeps YOLO disabled. ACP/structured sessions are intentionally
omitted.

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

Three optional profiles are installed:

- `codex --profile seo` enables the local Codex SEO suite, except integrations
  that require separately configured DataForSEO, Firecrawl, Google, or Gemini
  credentials.
- `codex --profile own` enables the hosted `own-context` MCP server.
- `codex --profile sentry` enables Sentry's official Codex plugin, all of its
  bundled skills, and its hosted MCP server.

AoE profiles named `seo`, `own`, and `sentry` launch Codex with those profile
flags in tmux mode. Use `aoe -p seo`, `aoe -p own`, or `aoe -p sentry`; each AoE
profile has its own session workspace. The Sentry AoE profile also supplies the
hosted MCP through its profile-local `mcp.json` for ACP sessions. ACP does not
currently activate the Codex profile's plugin skills.

On the NixOS `remote-dev` host, Home Manager installs
`reconcile-managed-agent-configs`. Activation and the Sentry plugin installer
both use this command so Codex's native plugin installation cannot leave the
plugin enabled in the default profile. The reconciler removes known legacy
values only when they still exactly match the old dotfiles-managed values.

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
