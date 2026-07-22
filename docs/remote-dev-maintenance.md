# Remote Dev Maintenance Runbook

This is the normal operating path after the server has been installed and public
SSH has been blocked.

## Regular Rebuild

On the server:

```bash
cd ~/dotfiles
git pull --ff-only
nix flake check ./nix --show-trace
nix build ./nix#nixosConfigurations.remote-dev.config.system.build.toplevel --no-link
sudo nixos-rebuild dry-activate --flake ./nix#remote-dev
sudo nixos-rebuild switch --flake ./nix#remote-dev
```

Or:

```bash
~/dotfiles/scripts/remote-dev/rebuild.sh
```

The script runs the same check, build, dry-activation, and switch sequence.

## Update Flake Inputs

Updates are manual in phase 1.

```bash
cd ~/dotfiles
scripts/remote-dev/update-flake.sh
git diff nix/flake.lock
scripts/remote-dev/rebuild.sh
scripts/remote-dev/verify-remote.sh
git status --short
git commit -am "Update remote dev flake inputs"
```

Before large updates, take a provider snapshot.

After the first server installation, do not routinely change
`systemStateVersion` or `homeStateVersion` in `nix/shared/vars.nix`. They are
compatibility baselines, not the installed NixOS and Home Manager release.

## Update the Rust Stable Toolchain

Nix owns the `rustup` executable, while rustup owns the mutable compiler
toolchains in the user's home directory. Update the global stable fallback
without asking rustup to replace its Nix-managed executable:

```bash
rustup update stable --no-self-update
rustup show active-toolchain
rustc --version
cargo --version
```

Projects may pin a different Rust version through mise, `rust-toolchain.toml`,
or a Nix development shell. Those project selections take precedence over the
global fallback.

## Roll Back a Bad Switch

If SSH still works:

```bash
sudo nixos-rebuild list-generations
sudo nixos-rebuild switch --rollback
```

If the machine is unreachable:

1. Try the Tailscale address or MagicDNS name.
2. Use the netcup console or rescue environment.
3. Boot a previous NixOS generation if the boot menu is reachable.
4. Restore a provider snapshot if needed.

## Disk Checks

Useful read-only checks:

```bash
df -h
sudo btrfs filesystem usage /
docker system df
ncdu /nix
ncdu /var/lib/docker
```

Manual cleanup only in phase 1:

```bash
sudo nix-collect-garbage
docker system prune
```

Do not run destructive cleanup commands until you understand what they will
remove. Keep Docker volumes with project databases especially visible.

## Secrets and Auth

These remain manual in phase 1:

- Tailscale login
- GitHub/GitLab CLI auth
- remote Git SSH key passphrase
- Codex/OpenAI auth
- company credentials
- project `.env` files

Do not commit raw secrets. Add `sops-nix` later only when a service needs a
secret during `nixos-rebuild` or systemd startup.

## Backups

Protected by Git/remotes:

- dotfiles and NixOS config
- committed branches
- pushed company/personal repos

Not protected automatically:

- uncommitted WIP
- untracked files
- local `.env` files
- Docker volumes and local databases
- remote SSH private keys
- auth state
- tmux resurrect state

Practical phase 1 discipline:

- push WIP branches often
- take provider snapshots before risky system changes
- keep credentials recoverable through a password manager or re-login
- avoid keeping important long-lived data only in Docker volumes

## Moving to a New Server

1. Provision a new VPS.
2. Update `nix/shared/vars.nix` if the disk name differs.
3. Run the first-install runbook.
4. Re-authenticate Tailscale, GitHub/GitLab, Codex, and company tools.
5. Clone project repos into your preferred locations.
6. Restore only the data you intentionally backed up.

## Codex and AoE dashboard

The persistent terminal-agent, worktree, Tailscale Funnel, Android, update, and
recovery procedures are documented in
[`remote-codex-aoe.md`](remote-codex-aoe.md).
