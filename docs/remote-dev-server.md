# Remote Dev Server Plan and Runbook

Status: planning document for the next implementation step.

This document captures the decisions from the remote development workstation
planning session. The next step is to implement this in the dotfiles repo as a
NixOS flake with reusable modules and an install/runbook flow.

## Goal

Create a personal remote development workstation that can be reached from
anywhere and used for:

- terminal-first development over SSH
- persistent `tmux` sessions
- running Codex and other coding agents on the remote machine
- browsing/editing code through VS Code Remote SSH
- running project Docker Compose stacks
- keeping the setup reproducible enough to move to a new server later

The remote server is the daily working machine, but it should be built with
rebuildability in mind: config in Git, minimal hand configuration, and clear
manual steps for auth/secrets.

## Phase 1 Scope

Phase 1 should build the useful remote workstation first:

- NixOS on an x86_64 netcup Root Server
- server-only install, no desktop/GUI
- OpenSSH over Tailscale for daily access
- public SSH only during bootstrap
- integrated Home Manager for user config
- btrfs disk layout with simple subvolumes
- Docker for project stacks
- zsh, tmux, Neovim, common CLI tools
- Node.js LTS, Bun, Python, uv, Rust via rustup
- direnv and nix-direnv for Nix-native per-project environments
- `mise` installed as compatibility glue only
- runbook docs for install, rebuild, updates, rollback, and manual auth

## Explicitly Out of Scope for Phase 1

Do not implement these yet:

- deSEC DNS
- public HTTPS services
- Caddy/Traefik/Nginx reverse proxy
- Tailscale SSH
- desktop or GUI stack
- Podman
- Playwright/Cypress/browser automation installed globally
- automatic NixOS updates
- automatic Docker/Nix cleanup jobs
- full file-level backups
- `sops-nix` / `age`
- `devenv` as a standard project tool
- tmux continuum or automatic tmux restore

These can be added later when there is a concrete need.

## Provider Decision

The target provider is netcup, using an x86_64 Root Server.

The exact plan can be chosen at purchase time:

- `RS 1000 G12`: acceptable trial size
- `RS 2000 G12`: preferred long-term workstation size

Use IPv4 + IPv6 connectivity. Do not choose IPv6-only for this first remote
workstation; compatibility and bootstrap simplicity are worth the small extra
cost.

Use a Europe location. The exact billing term and plan are intentionally left
to the user.

## Major Decisions

| Area | Decision |
| --- | --- |
| Workstation model | Persistent canonical remote workstation, but reproducible enough to rebuild |
| OS | NixOS |
| CPU architecture | x86_64, not ARM64 |
| Provider | netcup Root Server, exact plan chosen later |
| Network | IPv4 + IPv6 |
| Daily private access | Tailscale |
| SSH model | Normal OpenSSH over Tailscale |
| Tailscale SSH | Not used in phase 1 |
| DNS | Not needed in phase 1 |
| Public services | None in phase 1 |
| Public SSH | Temporary bootstrap only, then blocked |
| Disk filesystem | btrfs |
| Disk encryption | No full-disk encryption in phase 1 |
| Repo location | `~/dotfiles` for config, `~/work` for project repos |
| Docker | Docker only, no Podman initially |
| Home Manager | Integrated into NixOS flake |
| Updates | Manual only, locked flake inputs |
| Secrets | Manual auth initially, no `sops-nix` until needed |

## Decision Background Relevant to Implementation

This section records why the main decisions were made, so the implementation can
avoid reopening settled choices unless new constraints appear.

### Workstation Model

The remote machine should be the real daily development workstation:

- repos and WIP live on the remote server
- Codex and coding agents run on the remote server
- `tmux` keeps long-running terminal sessions alive
- VS Code Remote SSH attaches to the same filesystem when needed
- local laptops/desktops are mostly clients

The machine should still be rebuildable. The goal is not a disposable container
for every session; it is a persistent workstation with its setup captured in
Git/Nix and with manual secrets/auth documented.

### NixOS Choice

NixOS was chosen instead of normal Linux plus Home Manager because the user wants
the server itself to be reproducible and portable. The tradeoff is occasional
compatibility friction with prebuilt Linux binaries. To reduce that friction,
the phase 1 system should include `nix-ld` and should keep Docker available for
project stacks.

Do not try to convert all company projects to Nix in the first pass.

### Provider and Sizing

Provider exploration covered Hetzner, OVH, Contabo, Hostinger, and netcup.
The resulting target is netcup Root Server because it gives a good balance of
dedicated CPU, RAM, disk, EU location, and NixOS-friendly install paths.

The exact netcup plan is intentionally not fixed:

- `RS 1000 G12` is acceptable for a trial.
- `RS 2000 G12` is the more comfortable long-term workstation shape.

Memory guidance from the session:

- 8 GB RAM is the practical floor.
- 16 GB RAM is preferred for daily remote development.
- More disk is useful because Nix store, Docker images, repos, and databases can
  grow quickly.

ARM64 was rejected for this workstation because company repos, VS Code
extensions, Docker images, npm native packages, vendor CLIs, browser tooling,
and agent tooling are more predictable on x86_64.

### Access Model

Use Tailscale as the private network and normal OpenSSH as the login mechanism.

Do not use Tailscale SSH in phase 1. The normal OpenSSH path is more compatible
with VS Code Remote SSH, existing SSH habits, `scp`/`rsync`, Git, and standard
Linux recovery/debugging.

Public SSH is only for bootstrap. Once Tailscale SSH access through OpenSSH is
confirmed, public SSH should be blocked.

### DNS and Public Services

deSEC DNS was discussed but removed from phase 1. Tailscale MagicDNS is enough
for the remote dev workflow.

Add deSEC later only if there is a concrete public-service need, such as:

- public HTTPS previews
- external webhooks
- client/team demos
- DNS-01 certificates
- reverse proxy setup

No public web services are needed initially.

### Layout

The final chosen layout is home-centered:

- `~/dotfiles` for the canonical dotfiles/NixOS config repo
- `~/work` for project repos

A top-level `/work` was considered and rejected because it did not match the
user's mental model. Keep project repos inside `/home/microhoffman/work`.

### Tooling Boundary

Use Nix/Home Manager for the base workstation tools. Use Docker Compose for
project services and existing company stacks. Use `nix develop` plus
`direnv`/`nix-direnv` for Nix-native project environments. Keep `mise` installed
only as compatibility glue for repos that already use `.tool-versions`,
`.node-version`, `.ruby-version`, or asdf/mise workflows.

Do not standardize on `devenv` in phase 1. Plain `nix develop` is the default
Nix-native project path; use `devenv` later only for repos whose environment
becomes complex enough to justify services/process/task orchestration.

## Threat Model and Secrets

Without disk encryption, the VPS provider can in principle inspect disk
contents through the hypervisor, storage backend, snapshots, or rescue tooling.
Full-disk encryption mainly protects against offline disk/snapshot exposure. It
does not remove the need to trust the hypervisor while the machine is running.

Phase 1 deliberately avoids full-disk encryption because remote unlock makes
reboots and recovery more complex.

Do not commit raw secrets to Git.

Manual/auth-only items for phase 1:

- Tailscale login
- Codex/OpenAI login
- GitHub/GitLab CLI auth
- SSH key passphrases
- company credentials

Add `sops-nix` with `age` later only when a future service needs a secret during
`nixos-rebuild` or service startup.

## Filesystem Layout

Use btrfs with simple subvolumes and no snapshot automation initially.

Desired subvolumes:

```text
/        root
/home    home
/nix     nix
/var/log log
```

Use mount options:

```text
compress=zstd
noatime
```

User-facing layout:

```text
/home/microhoffman/dotfiles
/home/microhoffman/work
/home/microhoffman/work/companies
/home/microhoffman/work/personal
/home/microhoffman/work/scratch
```

The `~/work` directory should be created declaratively. Do not manage cloned
project repos declaratively in phase 1; clone them manually as needed.

## Proposed Repo Structure

Create this structure in the dotfiles repo during implementation:

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
      users.nix
      ssh.nix
      tailscale.nix
      docker.nix
      nix-ld.nix
      firewall.nix
      zram.nix
    home/
      zsh.nix
      tmux.nix
      git.nix
      dev-tools.nix
      neovim.nix
      ssh-agent.nix
  shared/
    vars.nix
docs/
  remote-dev-server.md
```

The implementation should follow the common Nix pattern: host files compose
reusable modules.

Host-specific values belong in:

```text
nix/hosts/remote-dev/default.nix
```

Reusable concerns belong in:

```text
nix/modules/nixos/*.nix
nix/modules/home/*.nix
```

Centralize only basic shared values, such as:

```text
username = "microhoffman";
homeDirectory = "/home/microhoffman";
workDirectory = "/home/microhoffman/work";
```

Avoid building a large custom option framework in phase 1.

## Nix Flake Direction

Use stable NixOS/nixpkgs for the system.

Use `flake.lock` and commit it. Updates should be intentional and committed.

Inputs likely needed:

- `nixpkgs`
- `home-manager`
- `disko`

Optional later:

- `sops-nix`
- `nix-vscode-server`
- `devenv`

Use Home Manager integrated into the NixOS system flake for the remote server.
One rebuild should apply both system and user config:

```bash
sudo nixos-rebuild switch --flake ~/dotfiles/nix#remote-dev
```

## NixOS Modules to Implement

### Users

Create user `microhoffman`.

Desired properties:

- normal user
- shell: zsh
- groups: `wheel`, `docker`
- passwordless sudo
- SSH key login only

Conceptual settings:

```nix
security.sudo.wheelNeedsPassword = false;
users.users.microhoffman.extraGroups = [ "wheel" "docker" ];
```

### SSH

Final state:

- password auth disabled
- root SSH disabled
- SSH reachable only over Tailscale
- public SSH blocked after bootstrap

Bootstrap needs public SSH temporarily for installation and first Tailscale
login.

Implement an explicit host option or variable:

```nix
allowPublicSsh = true;  # bootstrap
allowPublicSsh = false; # final state
```

The final firewall should allow SSH on `tailscale0` only.

### Tailscale

Enable the service declaratively:

```nix
services.tailscale.enable = true;
```

Initial join is manual:

```bash
sudo tailscale up --ssh=false
```

Do not put Tailscale auth keys in Git.

### Docker

Use Docker, not Podman, in phase 1.

```nix
virtualisation.docker.enable = true;
users.users.microhoffman.extraGroups = [ "docker" ];
```

Project runtimes and services should usually remain in each repo's Docker
Compose files.

### nix-ld

Enable `nix-ld` from day one to reduce friction with prebuilt binaries,
including VS Code Remote SSH server/extensions and random vendor CLIs.

### zram

Enable zram:

```nix
zramSwap.enable = true;
```

Do not add a disk swapfile initially.

## Home Manager Modules to Implement

### zsh

Use zsh with Oh My Zsh.

Theme:

```text
robbyrussell
```

Desired plugins:

```text
git
docker
docker-compose
sudo
systemd
fzf
```

Use persistent history:

- large history
- append history
- share history across sessions
- ignore duplicates
- ignore commands starting with a space

### tmux

Use Home Manager's `programs.tmux` and Nix-managed tmux plugins.

Do not manually install TPM.

Desired plugins:

- `tmux-sensible`
- `tmux-resurrect`

Do not install `tmux-continuum` initially.

Configure `tmux-resurrect` for manual save/restore, not automatic restore. Prefer
restoring layout/directories over aggressively restoring arbitrary running
processes.

Useful baseline settings:

- mouse enabled
- vi key mode
- large scrollback
- readable status
- truecolor-compatible terminal

### Neovim

Install Neovim with sane defaults, no heavy plugin setup.

Use:

```text
EDITOR=nvim
VISUAL=nvim
```

Sane defaults can include:

```vim
set number
set relativenumber
set expandtab
set shiftwidth=2
set tabstop=2
set smartindent
set ignorecase
set smartcase
```

### Dev Tools

Install a moderate toolkit through Home Manager:

```text
git
gh
curl
wget
jq
yq
ripgrep
fd
fzf
bat
eza
tree
tmux
htop or btop
unzip
zip
rsync
ncdu
direnv
nix-direnv
nodejs LTS
bun
python3
uv
rustup
mise
```

Also include database clients:

```text
psql
mysql or mariadb client
redis-cli
sqlite
```

Do not install database servers globally in phase 1.

### Tooling Rules

Use the following hierarchy:

```text
Nix/Home Manager:
  base workstation tools

nix develop + direnv:
  Nix-native project environments

Docker Compose:
  project services and company stacks

mise:
  compatibility glue when a repo already expects .tool-versions,
  .node-version, .ruby-version, or asdf/mise workflows
```

Prefer the Nix-native way where possible. Keep `mise` installed but do not make
it the primary package manager. Avoid global `mise use --global` for core tools.

Use `rustup` for Rust because this workstation needs normal Rust developer
workflows and ad hoc `cargo install` use cases, including tools such as
`agent-of-empires`. Use Nix dev shells or project-specific setup when a Rust
project needs reproducibility.

Use `uv` for Python tooling instead of global `pip install --user` sprawl.

## Agent and Auth Setup

Install prerequisites declaratively, but install/login agent tools manually
until the workflow stabilizes.

Declarative prerequisites:

```text
nodejs
bun
git
gh
ripgrep
fd
jq
tmux
nix-ld
```

Manual/private:

```text
Codex install/auth
OpenAI auth
GitHub/GitLab CLI auth
company credentials
```

Later, after the exact agent toolchain is stable, decide whether to pin parts of
it in Home Manager or document manual bootstrap commands.

## Git and SSH Keys

Use one global Git identity.

Generate a separate SSH key on the remote server for GitHub/GitLab access. Do
not copy the local workstation private key to the VPS.

Suggested command:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_remote_dev -C "remote-dev"
```

Use a passphrase.

Use a user-level `ssh-agent` on the server so Git operations do not ask for the
key passphrase every time. The passphrase is still entered manually after reboot
or when the key is not loaded.

Manual load:

```bash
ssh-add ~/.ssh/id_ed25519_remote_dev
```

Add the public key to GitHub/GitLab manually.

## Local Client SSH Config

Use a local SSH alias for convenience:

```sshconfig
Host remote-dev
  HostName <tailscale-magicdns-name-or-100.x.y.z>
  User microhoffman
  IdentityFile ~/.ssh/<local-client-key>
  ForwardAgent no
```

Use VS Code Remote SSH against this alias.

Example:

```bash
ssh remote-dev
code --remote ssh-remote+remote-dev /home/microhoffman/work
```

Do not forward the local SSH agent by default; the server has its own Git key.

## Initial Install Runbook

This is the expected high-level flow. Exact commands may change during
implementation.

### 1. Order Server

Choose:

- netcup Root Server x86_64
- RS 1000 G12 or RS 2000 G12
- IPv4 + IPv6
- Europe

### 2. Prepare dotfiles repo

Implement the Nix flake and modules in the local dotfiles repo.

Commit:

- `nix/flake.nix`
- `nix/flake.lock`
- host modules
- Home Manager modules
- runbook docs

### 3. Bootstrap public SSH

The initial server must be reachable by root SSH or equivalent rescue SSH for
`nixos-anywhere`.

### 4. Run nixos-anywhere

Initial install only:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake ~/dotfiles/nix#remote-dev \
  --target-host root@<public-ip>
```

This path is destructive when `disko` partitions/formats disks.

Never use this command for regular updates on a live system.

### 5. First login

SSH over public IP while bootstrap public SSH is still allowed:

```bash
ssh microhoffman@<public-ip>
```

### 6. Join Tailscale

Manual:

```bash
sudo tailscale up --ssh=false
```

Confirm the machine appears in the tailnet.

### 7. Confirm Tailscale SSH

From local machine:

```bash
ssh microhoffman@<tailscale-name-or-ip>
```

Then configure/update local SSH alias `remote-dev`.

### 8. Block public SSH

Flip:

```text
allowPublicSsh = false
```

Rebuild:

```bash
cd ~/dotfiles
sudo nixos-rebuild switch --flake ./nix#remote-dev
```

Confirm:

- SSH over Tailscale still works
- public SSH is blocked

## Regular Rebuild Runbook

Regular config changes should be applied on the server first.

```bash
cd ~/dotfiles
git pull
sudo nixos-rebuild switch --flake ./nix#remote-dev
```

If the repo is edited locally, push changes, then pull them on the server before
rebuilding.

## Updating Flake Inputs

Manual update only:

```bash
cd ~/dotfiles
nix flake update --flake ./nix
sudo nixos-rebuild switch --flake ./nix#remote-dev
git diff
git status
git commit
```

Before large updates, consider a netcup snapshot.

Do not enable unattended OS updates in phase 1.

## Rollback Basics

NixOS keeps boot generations. If a rebuild breaks something but SSH still
works, inspect generations and switch back using standard NixOS tools.

If the machine becomes unreachable:

1. Try Tailscale SSH path.
2. Use netcup console/rescue.
3. Boot previous NixOS generation if possible.
4. Use provider snapshot if needed.

The implementation runbook should add exact rollback commands once the flake is
in place.

## Disk Inspection

Install `ncdu` for interactive disk usage inspection.

Useful places to inspect:

```bash
ncdu /nix
ncdu /var/lib/docker
ncdu ~/work
ncdu ~
```

Useful non-destructive checks:

```bash
df -h
docker system df
```

Do not add scheduled cleanup in phase 1.

## Backups

Phase 1 relies on Git/remotes for code and config:

- dotfiles/NixOS config committed and pushed
- company repos pushed to their remotes
- personal repos pushed to their remotes

Not protected by Git unless handled separately:

- uncommitted WIP
- untracked files
- local `.env` files
- Docker volumes/databases
- remote server SSH private key
- Codex/auth state
- shell history
- tmux resurrect state
- downloaded artifacts

For phase 1:

- push WIP branches often
- use netcup snapshots before risky system changes
- keep secrets recoverable through password manager or re-login
- do not keep important long-lived data only in Docker volumes

Review netcup backup/snapshot options later.

## Validation Checklist

After implementation/install, verify:

- public SSH works during bootstrap
- NixOS install completes
- user `microhoffman` exists
- passwordless sudo works
- Tailscale joins successfully
- SSH over Tailscale works
- public SSH is blocked after final rebuild
- root SSH is disabled
- password SSH login is disabled
- VS Code Remote SSH opens `~/work`
- `tmux` starts and persists sessions
- `tmux-resurrect` manual save/restore works
- Docker works
- `docker compose` works in a sample/project repo
- `nix-ld` avoids VS Code server binary issues
- `direnv` and `nix-direnv` work
- Node.js, Bun, Python, uv, rustup, and mise are available
- database clients are available
- remote Git SSH key can clone/push to GitHub/GitLab
- Codex installs/logs in manually
- `sudo nixos-rebuild switch --flake ./nix#remote-dev` works from `~/dotfiles`

## Open Variables for Implementation

These are intentionally not decided in this document:

- exact netcup plan: RS 1000 G12 or RS 2000 G12
- final public IP
- final Tailscale MagicDNS name
- exact local SSH client key path
- exact Git commit name/email values
- whether to add `nix-vscode-server` later
- whether to add `sops-nix` later
- whether to add provider backups later

## Suggested Next Implementation Order

1. Add `nix/flake.nix` with stable nixpkgs, Home Manager, and disko.
2. Add shared vars for `microhoffman`, home directory, and work directory.
3. Add `hosts/remote-dev/default.nix`.
4. Add `hosts/remote-dev/disko.nix` with btrfs subvolumes.
5. Add system modules for users, SSH/firewall, Tailscale, Docker, nix-ld, zram.
6. Add Home Manager modules for zsh, tmux, git, Neovim, dev tools, ssh-agent.
7. Add `allowPublicSsh` bootstrap switch.
8. Add exact install/rebuild/update commands to this runbook.
9. Test flake evaluation locally if possible.
10. Install on the server with `nixos-anywhere`.
11. Join Tailscale manually.
12. Block public SSH and validate final state.

## Implementation Notes for Next Agent

The first implementation should create Nix files and scripts/docs only. It
should not need a real server IP until the install step.

Important constraints:

- Keep the flake target named `remote-dev`.
- Keep the system architecture `x86_64-linux`.
- Keep Home Manager integrated into the NixOS flake.
- Keep `~/dotfiles` and `~/work` as the expected remote paths.
- Keep public SSH as an explicit bootstrap/final switch.
- Keep Tailscale login manual.
- Keep raw secrets out of Git.
- Do not add `sops-nix`, public DNS, public services, GUI, Podman, or automatic
  updates in phase 1.

The initial implementation should be reviewable before running
`nixos-anywhere`. Avoid scripts that hide destructive behavior. If install
scripts are added, name them clearly and make destructive commands explicit.

## Suggested Skills for Future Sessions

Useful skills for the implementation session:

- `find-docs`: for current NixOS, Home Manager, disko, nixos-anywhere, and
  netcup-specific documentation.
- `diagnose`: if NixOS install, SSH, Tailscale, VS Code Remote SSH, Docker, or
  `nixos-rebuild` fails.
- `handoff`: if the implementation is not finished in one session and another
  agent needs a compact continuation document.
