# Remote Dev Implementation Handoff

This handoff records the implemented NixOS remote development workstation
baseline in this repo and the remaining manual install inputs.

Read the full plan first:

- [`remote-dev-server.md`](remote-dev-server.md)

That file is the source of truth for decisions, scope, module structure,
install flow, update flow, and validation. This handoff summarizes how to pick
up installation or further refinement.

## Current Repo State

- `nix/flake.nix` defines NixOS host `remote-dev`.
- `nix/flake.lock` pins the current inputs.
- `nix/hosts/remote-dev` contains the host, generic VPS hardware, and disko
  layout.
- `nix/modules/nixos` contains system modules for users, SSH/firewall,
  Tailscale, Docker, nix-ld, zram, base server settings, and directories.
- `nix/modules/home` contains Home Manager modules for zsh, tmux, Git, Neovim,
  ssh-agent, direnv/nix-direnv, and dev tools.
- `scripts/remote-dev` contains validation, destructive install, rebuild,
  update, and smoke-test helpers.
- `docs/remote-dev-first-install.md` and `docs/remote-dev-maintenance.md`
  contain the operational runbooks.

## Implemented Goal

The repo now has a NixOS flake for host `remote-dev` with integrated Home
Manager.

The setup is intended to support:

- NixOS install via `nixos-anywhere`
- btrfs disk layout via `disko`
- user `microhoffman`
- canonical dotfiles checkout at `~/dotfiles`
- Tailscale enabled, manual login
- normal OpenSSH over Tailscale
- public SSH allowed only during bootstrap
- Docker for project stacks
- `nix-ld` for prebuilt binary compatibility
- zsh + Oh My Zsh
- tmux with Nix-managed `tmux-sensible` and `tmux-resurrect`
- Neovim sane defaults
- base dev tools through Home Manager
- manual auth for Codex, GitHub/GitLab CLIs, Tailscale, and secrets

## Start Here

Before installing, review [`nix/shared/vars.nix`](../nix/shared/vars.nix), add a
real public SSH key, confirm the target disk, and run:

```bash
scripts/remote-dev/check-config.sh
```

Do not run `nixos-anywhere` until the flake, disko layout, SSH keys, and disk
name have been reviewed.

## Safety Boundaries

- `nixos-anywhere` is initial install/reinstall only and may wipe disks.
- Normal updates use `sudo nixos-rebuild switch --flake ./nix#remote-dev`.
- Keep public SSH as an explicit bootstrap/final switch.
- Do not commit raw secrets.
- Do not add `sops-nix` until there is a concrete rebuild-time secret.
- Do not add public DNS/services, GUI, Podman, automatic updates, or global
  browser testing stacks in phase 1.

## Open Inputs Needed Later

These can be filled in when the server exists:

- netcup plan actually selected: RS 1000 G12 or RS 2000 G12
- public IPv4/IPv6
- Tailscale MagicDNS name
- local SSH client key path
- Git user name/email exact values
- public SSH key to authorize for initial user access

Current phase-1 validation flow:

- Validate the flake:

  ```bash
  nix flake check ./nix --show-trace
  ```

- Build the remote system closure without switching or installing anything:

  ```bash
  nix build ./nix#nixosConfigurations.remote-dev.config.system.build.toplevel --no-link
  ```

- The install preflight is expected to fail with the staged defaults until
  `authorizedSshKeys` has at least one public key. After adding that key, run:

  ```bash
  scripts/remote-dev/check-config.sh
  ```

- If the local `/nix/store` is under pressure, use
  `REMOTE_DEV_NIX_STORE=/tmp/dotfiles-nix-store` with the preflight and
  `nix --store /tmp/dotfiles-nix-store build ...` for the system build.

- Local VM testing is intentionally skipped in phase 1. The pre-VPS confidence
  gate is config evaluation plus a full system build; runtime checks happen on
  the actual VPS after first boot.

## Suggested Skills

- `find-docs` for NixOS, Home Manager, disko, nixos-anywhere, tmux Home Manager
  options, Tailscale, and netcup docs.
- `diagnose` if installation, SSH, Tailscale, Docker, VS Code Remote SSH, or
  `nixos-rebuild` fails.
- `handoff` if implementation cannot be finished in one session.
