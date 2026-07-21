# Repository Guidelines

## Project Structure & Module Organization

This repo is a personal dotfiles and remote-workstation configuration repository.
The Nix flake lives in `nix/flake.nix`, with shared inputs in
`nix/shared/vars.nix`. The `remote-dev` NixOS host is defined under
`nix/hosts/remote-dev/`. Reusable NixOS modules live in `nix/modules/nixos/`,
and Home Manager modules live in `nix/modules/home/`. Operational scripts are in
`scripts/remote-dev/`; long-form runbooks and architecture notes are in `docs/`.
Cross-platform setup scripts and tool settings live under `setup/`, for example
`setup/agent-skills/` and `setup/vscode/`.

## Setup Portability

Prefer platform-agnostic setup when a tool or editor configuration should work
across local and remote machines, such as Fedora workstations and Nix remote
hosts. Keep those files under `setup/<tool>/` with explicit install scripts,
settings fragments, and README notes. Use Nix/Home Manager for NixOS-specific
system behavior, services, packages, or remote-dev host state, not as the
default place for portable editor and developer-tool preferences.

## Build, Test, and Development Commands

Run commands from the repository root unless noted otherwise.

```bash
nix flake check ./nix --show-trace
```

Evaluates the flake and catches invalid NixOS/Home Manager options.

```bash
nix build ./nix#nixosConfigurations.remote-dev.config.system.build.toplevel --no-link
```

Builds the remote system closure without switching or installing anything.

```bash
scripts/remote-dev/check-config.sh
```

Runs the install preflight. It intentionally fails until
`nix/shared/vars.nix` contains at least one public SSH key in
`authorizedSshKeys`.

## Coding Style & Naming Conventions

Use `nixfmt` for Nix files via the flake formatter. Keep modules small
and purpose-specific: one concern per file, named after the service or tool it
configures, for example `ssh.nix`, `tailscale.nix`, or `tmux.nix`. Shell scripts
should use Bash, `set -euo pipefail`, clear usage text, and explicit destructive
guards for risky operations.

## Testing Guidelines

Phase 1 does not use a local VM. The pre-VPS confidence gate is flake
evaluation, full system build, and `check-config.sh`. Runtime behavior is tested
after first boot with:

```bash
~/dotfiles/scripts/remote-dev/verify-remote.sh
```

## Commit & Pull Request Guidelines

Recent commits use short imperative summaries, for example
`add gitlab-create-mr skill install`. Keep commits focused by area: Nix config,
runbooks, or scripts. PRs should describe the operational impact, list commands
run, and call out any install, firewall, disk, or SSH behavior changes.

## Security & Configuration Tips

Do not commit private keys, API tokens, Tailscale auth keys, company
credentials, or project `.env` files. Public SSH keys are acceptable but reveal
identity metadata. Keep `allowPublicSsh = true` only for bootstrap, then switch
it to `false` after Tailscale SSH access is verified.
