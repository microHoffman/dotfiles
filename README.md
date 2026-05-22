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
| `create-pull-request` | https://github.com/microHoffman/agent-skills | `setup/agent-skills/install-create-pull-request.sh` |
| `github-issues` | https://github.com/microHoffman/agent-skills | `setup/agent-skills/install-github-issues.sh` |
| `gitlab-create-mr` | https://github.com/microHoffman/agent-skills | `setup/agent-skills/install-gitlab-create-mr.sh` |

## Useful guides

### VS Code setup

Portable VS Code extension and settings setup lives in
[`setup/vscode`](setup/vscode). Run:

```bash
setup/vscode/install.sh
```

### remote dev server

Planning and architecture notes for the NixOS remote workstation live in
[`docs/remote-dev-server.md`](docs/remote-dev-server.md).

Operational runbooks:

- [`docs/remote-dev-first-install.md`](docs/remote-dev-first-install.md)
- [`docs/remote-dev-maintenance.md`](docs/remote-dev-maintenance.md)
- [`docs/remote-dev-implementation-handoff.md`](docs/remote-dev-implementation-handoff.md)

The flake entrypoint is [`nix/flake.nix`](nix/flake.nix) and the host target is
`remote-dev`.

### ssh-agent setup on hyprland

https://www.lorenzobettini.it/2023/09/hyprland-and-ssh-agent/
