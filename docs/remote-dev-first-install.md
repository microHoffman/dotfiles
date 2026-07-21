# Remote Dev First Install Runbook

This is the first-install path for the `remote-dev` NixOS workstation. It is
for a new or intentionally reinstalled VPS only.

## 1. Fill Local Inputs

Edit [`nix/shared/vars.nix`](../nix/shared/vars.nix) before running the install.

Required:

- `installDisk`: confirm the target disk in rescue mode with `lsblk`
- `authorizedSshKeys`: add at least one local client public SSH key
- `allowPublicSsh = true`: keep this true only for bootstrap

Optional before first install:

- `git.userName`
- `git.userEmail`
- `timeZone`

Do not put private keys, API tokens, Tailscale auth keys, or company credentials
in this repo.

## 2. Validate Locally

Phase 1 does not use a local VM. The local gate is: evaluate the flake, build
the NixOS system closure, then check the install inputs. Runtime behavior is
verified after the real VPS boots.

From the repo root, first validate that the NixOS and Home Manager config
evaluates:

```bash
nix flake check ./nix --show-trace
```

Then build the remote system closure without switching or installing anything:

```bash
nix build ./nix#nixosConfigurations.remote-dev.config.system.build.toplevel --no-link
```

After adding at least one real public key to `authorizedSshKeys`, run the
install preflight:

```bash
scripts/remote-dev/check-config.sh
```

This checks that at least one SSH public key is configured and then runs
`nix flake check` against the remote-dev flake. With the staged defaults this
fails until `authorizedSshKeys` has at least one public key.

If the local machine has `/nix/store` space or Btrfs metadata pressure, use a
temporary store for the build and preflight:

```bash
nix --store /tmp/dotfiles-nix-store build \
  ./nix#nixosConfigurations.remote-dev.config.system.build.toplevel \
  --no-link
```

```bash
REMOTE_DEV_NIX_STORE=/tmp/dotfiles-nix-store \
  scripts/remote-dev/check-config.sh
```

For a syntax/evaluation-only check before adding the SSH key, use:

```bash
nix --store /tmp/dotfiles-nix-store eval \
  path:$PWD/nix#nixosConfigurations.remote-dev.config.system.build.toplevel.drvPath \
  --raw
```

Do not run `system.build.vm` as part of this phase. A local VM can be added
later if runtime testing before VPS install becomes worth the extra setup.

## 3. Prepare the VPS

Order or reset the target server:

- netcup Root Server
- x86_64
- IPv4 + IPv6
- NixOS-compatible rescue or minimal Linux environment
- public root SSH access for bootstrap
- UEFI boot enabled in the netcup SCP

In rescue mode, confirm the install disk:

```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS
```

The default config expects `/dev/vda`. Change `installDisk` if the actual disk is
different. The install uses `disko` and can repartition and format that disk.

## 4. Run Destructive Install

From the local repo root:

```bash
REMOTE_DEV_CONFIRM_DESTROY=yes \
  scripts/remote-dev/install-destroy-with-nixos-anywhere.sh root@<public-ip>
```

For a slow source-machine connection, build the system closure on the VPS so
the large binary-cache downloads use the VPS connection:

```bash
REMOTE_DEV_BUILD_ON=remote \
REMOTE_DEV_CONFIRM_DESTROY=yes \
  scripts/remote-dev/install-destroy-with-nixos-anywhere.sh root@<public-ip>
```

If you are using the temporary Nix store workaround, pass it to the install
script too. The helper applies it to the outer `nix run` and exports
`NIX_REMOTE` for nested Nix calls:

```bash
REMOTE_DEV_NIX_STORE=/tmp/dotfiles-nix-store \
REMOTE_DEV_CONFIRM_DESTROY=yes \
  scripts/remote-dev/install-destroy-with-nixos-anywhere.sh root@<public-ip>
```

The script runs:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake path:<repo>/nix#remote-dev \
  --build-on <auto|local|remote> \
  --target-host root@<public-ip>
```

Use this only for initial install or intentional reinstall. Regular updates use
`nixos-rebuild`, not `nixos-anywhere`. The script refuses to install when
`allowPublicSsh = false` because the fresh host has not joined Tailscale yet.
Override with `REMOTE_DEV_ALLOW_NO_PUBLIC_SSH=yes` only if you have another
confirmed first-login path.

## 5. First Login and Git Bootstrap

After the install reboots:

```bash
ssh microhoffman@<public-ip>
```

If the dotfiles repo is cloned over SSH, create the remote-only Git key before
the first clone:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_remote_dev -C "remote-dev"
ssh-add ~/.ssh/id_ed25519_remote_dev
cat ~/.ssh/id_ed25519_remote_dev.pub
```

Add that public key to GitHub/GitLab from a local browser. Test GitHub SSH
authentication before cloning:

```bash
ssh -T git@github.com
```

GitHub should identify the expected account and report that authentication
succeeded. Then clone or pull this dotfiles repo into the expected path:

```bash
git clone <dotfiles-repo-url> ~/dotfiles
```

If `~/dotfiles` already exists and is empty, clone into it directly. If it has
files, inspect it before replacing anything.

## 6. Join Tailscale

On the server:

```bash
sudo tailscale up --ssh=false
```

Confirm the node appears in the tailnet. Daily access is normal OpenSSH over the
Tailscale address or MagicDNS name, not Tailscale SSH.

From the local client:

```bash
ssh microhoffman@<tailscale-name-or-ip>
```

## 7. Block Public SSH

After normal OpenSSH over Tailscale works, edit:

```nix
allowPublicSsh = false;
```

Then rebuild on the server:

```bash
cd ~/dotfiles
sudo nixos-rebuild switch --flake ./nix#remote-dev
```

Confirm:

```bash
ssh microhoffman@<tailscale-name-or-ip>
ssh -o ConnectTimeout=5 microhoffman@<public-ip>
```

The Tailscale path should work. The public IP path should fail.

## 8. Local SSH Alias

On each local client, add:

```sshconfig
Host remote-dev
  HostName <tailscale-magicdns-name-or-100.x.y.z>
  User microhoffman
  IdentityFile ~/.ssh/<local-client-key>
  ForwardAgent no
```

Then use:

```bash
ssh remote-dev
code --remote ssh-remote+remote-dev /home/microhoffman/dotfiles
```

## 9. Manual Auth

The remote-only Git key was loaded into the server ssh-agent during bootstrap.
The agent does not retain unlocked keys across a reboot, so load it again after
each reboot before Git operations:

```bash
ssh-add ~/.ssh/id_ed25519_remote_dev
```

Then authenticate tools manually:

```bash
gh auth login -h github.com
glab auth login
```

Install Codex/AoE configuration and the desired global skills, then initialize
GitHits:

```bash
cd ~/dotfiles
setup/aoe-remote/install-config.sh
setup/agent-skills/install-all-global.sh
setup/githits/init.sh
```

Repository-specific skills are installed only after those repositories are
cloned. If they already exist, use `setup/agent-skills/install-all.sh` with
their exact paths instead of `install-all-global.sh` above. If they are cloned
later, use the corresponding individual repository installer so the global set
is not needlessly reinstalled. The PWN Protocol installer is the only Trail of
Bits target; do not run it in Proof of Presence.

Continue with [`remote-codex-aoe.md`](remote-codex-aoe.md) to install and log in
to Codex and AoE. Its Tailscale operator, Funnel, lingering, and dashboard flags
are separate approval gates and remain disabled during initial installation.

## 10. Validate

On the server:

```bash
~/dotfiles/scripts/remote-dev/verify-remote.sh
```

Also verify manually:

- `tmux` sessions survive SSH disconnect/reconnect
- `tmux-resurrect` manual save/restore works
- VS Code Remote SSH opens `/home/microhoffman/dotfiles`
- Docker Compose works in a real project repo
- `nix develop` + `direnv` works in a sample Nix project
- Git clone/push works through the remote-only SSH key
