## Setup approach

Portable developer setup lives under `setup/` when it can reasonably work across
machines, including local Fedora workstations and Nix remote hosts. Prefer this
for editor settings, CLI bootstrap scripts, and tool-specific configuration that
is not inherently tied to NixOS.

Use the Nix flake for the remote-dev host, system services, and NixOS/Home
Manager state where declarative Nix is the right portability boundary.

## Agent skills

Skill source remains in its upstream repository. Dotfiles keeps one installer
per skill so the selected set is readable and independently updatable. The
aggregate installer uses the same helpers and sources, grouping skills by
upstream repository to avoid redundant clones.

Install or update the global set:

```bash
setup/agent-skills/install-all-global.sh
```

| Global skill/tool | Source | Individual installer |
| --- | --- | --- |
| `activecollab` | `microHoffman/agent-skills` | `install-activecollab.sh` |
| `agent-browser` CLI + skill | `vercel-labs/agent-browser` | `install-agent-browser.sh` |
| `create-pull-request` | `microHoffman/agent-skills` | `install-create-pull-request.sh` |
| `github-issues` | `microHoffman/agent-skills` | `install-github-issues.sh` |
| `gitlab-create-mr` | `microHoffman/agent-skills` | `install-gitlab-create-mr.sh` |
| `develop-secure-contracts` | `OpenZeppelin/openzeppelin-skills` | `install-develop-secure-contracts.sh` |
| `upgrade-solidity-contracts` | `OpenZeppelin/openzeppelin-skills` | `install-upgrade-solidity-contracts.sh` |
| `diagnosing-bugs` | `mattpocock/skills` | `install-diagnosing-bugs.sh` |
| `code-review` | `mattpocock/skills` | `install-code-review.sh` |
| `codebase-design` | `mattpocock/skills` | `install-codebase-design.sh` |
| `domain-modeling` | `mattpocock/skills` | `install-domain-modeling.sh` |
| `grilling` | `mattpocock/skills` | `install-grilling.sh` |
| `grill-me` | `mattpocock/skills` | `install-grill-me.sh` |
| `grill-with-docs` | `mattpocock/skills` | `install-grill-with-docs.sh` |
| `improve-codebase-architecture` | `mattpocock/skills` | `install-improve-codebase-architecture.sh` |
| `research` | `mattpocock/skills` | `install-research.sh` |
| `resolving-merge-conflicts` | `mattpocock/skills` | `install-resolving-merge-conflicts.sh` |
| `handoff` | `mattpocock/skills` | `install-handoff.sh` |
| `teach` | `mattpocock/skills` | `install-teach.sh` |
| Sentry Codex plugin, skills, and MCP | `getsentry/plugin-codex` | `install-sentry-plugin.sh` |
| Codex SEO suite | `AgriciDaniel/codex-seo` | `install-codex-seo.sh` |

The remote-dev Home Manager profile includes `glab`. After `glab auth login`
for `gitlab.tomatom.cz`, `gitlab-create-mr` prefers that authenticated CLI and
falls back to its bundled `GITLAB_TOKEN` helper only when the CLI is unavailable
or unauthenticated.

The SEO suite and official Sentry plugin are installed physically but disabled
by the base Codex config; start `codex --profile seo` or
`codex --profile sentry` to enable them. The Sentry plugin supplies its complete
upstream skill set and hosted MCP configuration without a dotfiles-maintained
skill wrapper. `grill-me`, `grill-with-docs`,
`improve-codebase-architecture`, `handoff`, and `teach` retain the upstream
explicit-only policy.

Repository-specific skills are deliberately absent from the global set:

| Repository target | Skills | Installer |
| --- | --- | --- |
| Depoto Client | `tanstack-query-angular` | `install-tanstack-query-angular.sh PATH` |
| `own_mcp` | `mcp-builder` | `install-mcp-builder.sh PATH` |
| PWN Protocol | Trail of Bits security workflow set | `install-pwn-protocol-skills.sh PATH` |

The PWN Protocol set contains `secure-workflow-guide`, `entry-point-analyzer`,
`property-based-testing`, `differential-review`, `fp-check`, and
`spec-to-code-compliance`. It is not installed in Proof of Presence.

To run global installation plus any repository targets that already exist:

```bash
setup/agent-skills/install-all.sh \
  --depoto-client ~/tomatom/client \
  --own-mcp ~/own/own_mcp \
  --pwn-protocol ~/pwn/pwn_protocol
```

All three repository flags are optional. The installer does not search for
repositories and does not try to deduplicate global and repository-local skills.

## Documentation access

After authenticating GitHub CLI, initialize GitHits with its official
interactive setup:

```bash
setup/githits/init.sh
```

GitHits owns the machine-local integration it generates. No duplicate GitHits
wrapper skill or hand-written GitHits block is maintained in `AGENTS.md`.

## Useful guides

### ActiveCollab agent setup

Install the ActiveCollab CLI and companion agent skill together on Fedora or
NixOS with:

```bash
setup/agent-skills/install-activecollab.sh
```

The installer uses mise to select the latest stable CLI release in
`~/.config/mise/conf.d/activecollab-cli.toml`, verifies that it is version 0.3.0
or newer, and installs the skill globally for all supported agents. Rerun the
same command to update both. To install a specific compatible CLI release, set
`ACTIVECOLLAB_CLI_VERSION` for that invocation.

The installer does not handle credentials. Log in afterward with the complete
self-hosted API-v1 URL:

```bash
activecollab auth login --url https://activecollab.example.com/api/v1
activecollab auth status
activecollab info
```

The CLI stores the URL, account, and token in a protected per-user credentials
file. For CI or ephemeral sessions, use protected `ACTIVECOLLAB_URL` and
`ACTIVECOLLAB_TOKEN` environment variables instead. Never commit credentials or
pass them in command arguments.

### VS Code setup

Portable VS Code extension and settings setup lives in
[`setup/vscode`](setup/vscode). Run:

```bash
setup/vscode/install.sh
```

### Codex mise setup

Portable Codex shell setup for mise-managed `node`, `npm`, and `npx` lives in
[`setup/codex-mise`](setup/codex-mise). Run:

```bash
setup/codex-mise/install.sh
```

### Local workstation zsh setup

Local-PC-only zsh helpers live in [`setup/zsh`](setup/zsh). Install them from
the dotfiles repository on the local PC:

```bash
setup/zsh/install.sh
```

This currently provides `shopty-tunnel` for forwarding the local privileged
HTTP port to the Shopty container on `remote-dev`. It is deliberately not
installed by the remote host's Home Manager configuration.

### Remote Codex and Agent of Empires

Portable, non-secret setup files live in
[`setup/aoe-remote`](setup/aoe-remote). The complete approval-gated NixOS,
Tailscale Funnel, systemd, Android, workflow, and recovery guide is
[`docs/remote-codex-aoe.md`](docs/remote-codex-aoe.md).

### remote dev server

Planning and architecture notes for the NixOS remote workstation live in
[`docs/remote-dev-server.md`](docs/remote-dev-server.md).

Operational runbooks:

- [`docs/remote-dev-first-install.md`](docs/remote-dev-first-install.md)
- [`docs/remote-dev-maintenance.md`](docs/remote-dev-maintenance.md)
- [`docs/remote-codex-aoe.md`](docs/remote-codex-aoe.md)
- [`docs/remote-dev-implementation-handoff.md`](docs/remote-dev-implementation-handoff.md)

The flake entrypoint is [`nix/flake.nix`](nix/flake.nix) and the host target is
`remote-dev`.

### ssh-agent setup on hyprland

https://www.lorenzobettini.it/2023/09/hyprland-and-ssh-agent/
