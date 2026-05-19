# Remote Dev Implementation Handoff

This handoff is for the next session that implements the NixOS remote
development workstation in this repo.

Read the full plan first:

- [`remote-dev-server.md`](remote-dev-server.md)

That file is the source of truth for decisions, scope, module structure,
install flow, update flow, and validation. This handoff only summarizes how to
pick up the implementation.

## Current Repo State

- The dotfiles repo is intentionally small.
- Planning docs have been added under `docs/`.
- `README.md` links to the remote dev docs.
- No Nix implementation files have been created yet.

## Implementation Goal

Create a NixOS flake for host `remote-dev` with integrated Home Manager.

The resulting setup should support:

- NixOS install via `nixos-anywhere`
- btrfs disk layout via `disko`
- user `microhoffman`
- home-centered layout: `~/dotfiles` and `~/work`
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

Follow the implementation order in `remote-dev-server.md`.

Expected first files:

```text
nix/
  flake.nix
  hosts/
    remote-dev/
      default.nix
      disko.nix
      hardware.nix
  modules/
    nixos/
    home/
  shared/
    vars.nix
```

Do not run `nixos-anywhere` until the flake and disko layout have been reviewed.

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

## Suggested Skills

- `find-docs` for NixOS, Home Manager, disko, nixos-anywhere, tmux Home Manager
  options, Tailscale, and netcup docs.
- `diagnose` if installation, SSH, Tailscale, Docker, VS Code Remote SSH, or
  `nixos-rebuild` fails.
- `handoff` if implementation cannot be finished in one session.
