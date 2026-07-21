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
enables the normal worktree workflow, preserves explicit conversation resume,
and keeps YOLO disabled. ACP/structured sessions are intentionally omitted.

Sentry MCP is disabled for the default `codex` tool. Choose `codex-sentry` in
AoE's agent picker to start Codex with Sentry enabled for that session only.
Authentication remains an explicit user action:

```bash
codex -c mcp_servers.sentry.enabled=true mcp login sentry
```

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
