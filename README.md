## Setup approach

Portable developer setup lives under `setup/` when it can reasonably work across
machines, including local Fedora workstations and Nix remote hosts. Prefer this
for editor settings, CLI bootstrap scripts, and tool-specific configuration that
is not inherently tied to NixOS.

Use the Nix flake for the remote-dev host, system services, and NixOS/Home
Manager state where declarative Nix is the right portability boundary.

## Agent skills

This dotfiles repo installs personal agent skills by reference. The skill source
code lives in its own repository; this repo only keeps the setup entrypoint.
Local source checkouts for development live under `~/myrepos`; dotfiles installs
published skills with `npx skills add`.

| Skill | Repository | Installer |
| --- | --- | --- |
| `activecollab` | https://github.com/microHoffman/agent-skills | `setup/agent-skills/install-activecollab.sh` |
| `create-pull-request` | https://github.com/microHoffman/agent-skills | `setup/agent-skills/install-create-pull-request.sh` |
| `github-issues` | https://github.com/microHoffman/agent-skills | `setup/agent-skills/install-github-issues.sh` |
| `gitlab-create-mr` | https://github.com/microHoffman/agent-skills | `setup/agent-skills/install-gitlab-create-mr.sh` |

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
