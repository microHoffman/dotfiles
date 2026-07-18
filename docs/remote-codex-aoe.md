# Remote Codex and Agent of Empires Runbook

This runbook adds a persistent personal Codex environment to the NixOS
`remote-dev` host. Normal OpenSSH runs over Tailscale. Agent of Empires manages
terminal-based Codex processes in tmux and publishes only its loopback web
dashboard through Tailscale Funnel.

The configuration is intentionally staged. These values default to `false` in
`nix/shared/vars.nix`:

```nix
aoeDashboard = {
  enable = false;
  enableTailscaleOperator = false;
  enableUserLinger = false;
};
```

Do not enable them until their approval steps below are complete. Nix evaluation
rejects `enable = true` unless both prerequisite gates are also enabled.

## Security model

- OpenSSH uses separate laptop and Android Ed25519 keys. Tailscale SSH is off.
- Public SSH is bootstrap-only. The final firewall accepts SSH on `tailscale0`
  and never opens TCP 8080.
- AoE binds explicitly to `127.0.0.1:8080`.
- Funnel is the only public transport. The launcher refuses to run when
  `cloudflared` is on `PATH`.
- AoE remote auth keeps its rotating URL token plus a strong passphrase.
- Codex uses `workspace-write`, `on-request`, and automatic approval review.
  Auto-review is not YOLO: the sandbox remains active and risky actions can be
  denied.
- Only the dashboard starts automatically. Old Codex agents are resumed
  deliberately after reboot.
- Current AoE releases otherwise recover missing tmux sessions when the web
  daemon starts. The service launcher prevents that on the first dashboard
  start of each host boot by archiving only sessions without a live tmux pane.
  Archive is reversible and preserves worktrees, branches, and transcripts.

## Phase 1: audit the actual VPS

Run these read-only checks before installing or changing anything:

```bash
cat /etc/os-release
uname -a
id
getent passwd "$USER"
printf '%s\n' "$SHELL"
systemd-detect-virt
systemctl status sshd tailscaled --no-pager
systemctl --user list-unit-files
loginctl show-user "$USER" -p Linger
command -v sshd tailscale tmux git node npm codex aoe
tmux -V
git --version
node --version
npm --version
codex --version
aoe --version
ss -lntup
sudo nft list ruleset
tailscale status
tailscale funnel status
```

The `sudo nft` command is privileged but read-only. Show it and obtain approval
before running it. Inspect and back up these paths when they exist:

```text
~/.codex/config.toml
~/.config/agent-of-empires/config.toml
~/.config/systemd/user/
~/.tmux.conf
```

Also verify the provider firewall and test the VPS public IPv4 and IPv6 from a
different network. TCP 8080 must fail from outside.

## Phase 2: install only missing components

Tailscale, OpenSSH, Git, tmux, Node.js, Docker, and mise are declared by NixOS
or Home Manager. Add or remove persistent general CLI tools in
`nix/modules/home/dev-tools.nix`.

Codex and AoE are fast-moving user tools. Install only missing binaries with:

```bash
cd ~/dotfiles
setup/aoe-remote/install-user-tools.sh codex aoe
```

The script downloads each official installer to a temporary directory, displays
its SHA-256 digest, opens it for review, and requires an exact confirmation.
It preserves any existing installation rather than changing provenance.

Seed application configuration before the first launch:

```bash
setup/aoe-remote/install-config.sh
```

Existing files are never overwritten. Compare and merge manually if the target
already has configuration.

Authenticate Codex interactively on the headless server:

```bash
codex login --device-auth
codex login status
```

## Phase 3: OpenSSH over Tailscale

Join the host without enabling Tailscale SSH:

```bash
sudo tailscale up --ssh=false
```

Effect: joins the VPS to the tailnet. Undo: `sudo tailscale logout`. Public SSH
is unaffected while joining; logout later interrupts Tailscale connectivity.

Verify normal OpenSSH from a second terminal using the Tailscale IP or MagicDNS
name. Only then set `allowPublicSsh = false` and rebuild. That rebuild can end a
public-IP SSH connection, so keep a verified Tailscale SSH session and provider
console available.

## Phase 4: Tailscale operator approval

The user systemd service must be able to invoke `tailscale funnel` without sudo.
After approval, set:

```nix
aoeDashboard.enableTailscaleOperator = true;
```

The NixOS rebuild runs the equivalent of:

```bash
sudo tailscale set --operator=microhoffman
```

Effect: `microhoffman` can manage this node's Tailscale daemon. Undo:
`sudo tailscale set --operator=root`. It does not interrupt SSH.

## Phase 5: Funnel exposure approval

Before enabling Funnel, display the resolved values and obtain confirmation:

- Public URL: `https://<machine>.<tailnet>.ts.net` on HTTPS 443.
- Destination: only `127.0.0.1:8080` on the VPS.
- Public content: the AoE login page. A first login requires both the URL token
  and passphrase.
- Risk: an authenticated dashboard provides terminal input and therefore remote
  code execution as the host user.
- Metadata: the machine and tailnet DNS names appear in the public hostname.

Enable the tailnet-wide Funnel feature in the Tailscale admin console. Merge a
least-privilege node attribute into the existing policy, targeting only the
server's assigned Tailscale IP:

```json
"nodeAttrs": [
  {
    "target": ["<SERVER_TAILSCALE_IP>"],
    "attr": ["funnel"]
  }
]
```

Never replace the rest of the policy. Verify:

```bash
tailscale status
tailscale funnel status
```

To disable public transport immediately:

```bash
tailscale funnel --https=443 off
```

Run `tailscale funnel status` before considering `tailscale funnel reset`;
`reset` removes every Funnel mapping on the node.

## Phase 6: passphrase, lingering, and dashboard

Generate at least 24 random characters in a password manager. Store it through
the hidden prompt, never as a shell argument:

```bash
setup/aoe-remote/set-passphrase.sh
```

This creates `~/.config/aoe-dashboard/serve.env` in an owner-only directory with
mode `0600`.

Lingering lets the user systemd manager start at boot and continue after logout.
After its separate approval, set:

```nix
aoeDashboard.enableUserLinger = true;
```

This is the declarative equivalent of:

```bash
sudo loginctl enable-linger microhoffman
```

Undo: `sudo loginctl disable-linger microhoffman`. It does not affect SSH and
does not start old agents.

After operator, Funnel, passphrase, and linger verification, set:

```nix
aoeDashboard.enable = true;
```

Review the generation before switching:

```bash
cd ~/dotfiles
nix flake check ./nix --show-trace
nix build ./nix#nixosConfigurations.remote-dev.config.system.build.toplevel --no-link
sudo nixos-rebuild dry-activate --flake ./nix#remote-dev
sudo nixos-rebuild switch --flake ./nix#remote-dev
```

The generated user unit runs `aoe serve --remote --host 127.0.0.1 --port 8080`
in the foreground with `Restart=on-failure`. It does not use `--daemon`.
`KillMode=process` prevents a dashboard stop from killing separately managed
tmux processes.

## Normal session workflow

Opening AoE over SSH remains:

```bash
ssh remote-dev
aoe
```

Plain `aoe` opens the normal TUI using the same user, AoE state, and tmux server
as the dashboard service. Press `R` if the TUI asks to attach to the running web
daemon or show its QR screen.

Create one outcome-oriented worktree session per concurrent task:

```bash
aoe add ~/work/personal/example \
  --title fix-refresh-token \
  --worktree fix-refresh-token \
  --new-branch \
  --tool codex \
  --launch
```

Do not add `--yolo` or `--structured-view`. Keep the main checkout for review,
testing, integration, and merging.

Useful lifecycle commands:

```bash
aoe list
aoe session attach fix-refresh-token
aoe session stop fix-refresh-token
aoe session start fix-refresh-token
aoe session archive fix-refresh-token
aoe worktree info fix-refresh-token
tmux list-sessions
```

After review, tests, commit, push, and merge:

```bash
aoe session archive fix-refresh-token
aoe remove fix-refresh-token --delete-worktree --delete-branch
```

AoE archive preserves the managed worktree. The second command performs the
supported cleanup and moves session metadata to recoverable trash. Avoid
`--force` and `--purge` during normal operation.

## Dashboard and phone operations

Show the live URL or QR locally over SSH:

```bash
aoe url
aoe
```

Treat the `?token=...` query as sensitive and redact it from screenshots,
messages, issues, and logs.

On Android:

1. Scan the live QR with the camera.
2. Enter the AoE passphrase from the password manager.
3. In Chrome, choose **Install app** or **Add to Home screen**.
4. Review or revoke devices under **Settings > Web Dashboard > Connected
   Devices**.

The Funnel PWA does not require the Tailscale Android app. Full SSH does:

1. Install Tailscale Android and join the same tailnet.
2. Generate a dedicated Ed25519 key in an Android SSH client.
3. Add only its public key to `authorizedSshKeys` and rebuild.
4. Connect to `microhoffman@<tailscale-magicdns-name>`.

If the phone is lost, remove it from the tailnet, remove its SSH public key and
rebuild, revoke its AoE dashboard device, and rotate the AoE passphrase.

## Three persistence layers

- **Live process persistence:** tmux/AoE keeps Codex alive across laptop,
  browser, SSH, and network disconnects. Live processes do not survive a host
  reboot.
- **Conversation persistence:** `codex resume` reloads a stored conversation
  after the process has ended or the server has rebooted.
- **Code persistence:** worktree files and branches persist on disk. Commits and
  remote pushes are the durable recovery boundary.

After reboot, the dashboard returns through systemd and lingering, but old
agents stay stopped. They appear archived because the boot guard uses AoE's
supported, reversible archive state to suppress automatic startup recovery.
Recover deliberately:

```bash
aoe list
tmux list-sessions
git -C <main-checkout> worktree list
git -C <worktree> status
aoe session unarchive <session>
aoe session start <session>
```

If AoE cannot resume it, enter the worktree and use:

```bash
codex resume
```

tmux-resurrect remains manual and does not automatically restore Codex agents.

## Service operations

```bash
systemctl --user status aoe-dashboard
systemctl --user stop aoe-dashboard
systemctl --user start aoe-dashboard
systemctl --user restart aoe-dashboard
journalctl --user -u aoe-dashboard
```

Stopping or restarting only the dashboard must leave existing tmux sessions
alive. Funnel configuration persists in `tailscaled`; stopping AoE makes the
public endpoint unavailable but does not remove the Funnel mapping. Use the
explicit Funnel-off command for emergency shutdown.

## Updating tools

First inspect installation provenance:

```bash
command -v codex aoe
codex --version
aoe --version
```

For an AoE official release installation:

```bash
systemctl --user stop aoe-dashboard
aoe update
systemctl --user start aoe-dashboard
```

Managed tmux sessions should survive because the unit uses `KillMode=process`;
verify before and after. Update Codex using the same official installation
method originally used. Do not mix standalone, npm, Cargo, and Nix provenance.

## Installing future tooling

- General user CLI: add it to `home.packages` in
  `nix/modules/home/dev-tools.nix`.
- System service or networking feature: add a focused module under
  `nix/modules/nixos/`.
- Project-pinned toolchain: commit `.mise.toml` or a Nix dev shell in the
  project repository.
- Temporary tool: use `nix shell nixpkgs#<tool>` or `nix run`.
- Fast-moving user binary unsuitable for Nixpkgs: add a reviewed portable
  installer under `setup/<tool>/`.

Use an outcome-oriented dotfiles worktree, validate, commit, merge, then apply:

```bash
nix flake check ./nix --show-trace
nix build ./nix#nixosConfigurations.remote-dev.config.system.build.toplevel --no-link
sudo nixos-rebuild dry-activate --flake ./nix#remote-dev
sudo nixos-rebuild switch --flake ./nix#remote-dev
```

Rollback:

```bash
sudo nixos-rebuild switch --rollback
```

## Verification

On the host:

```bash
~/dotfiles/scripts/remote-dev/verify-remote.sh
~/dotfiles/scripts/remote-dev/verify-aoe.sh
```

Then create a disposable Git repository and AoE worktree. Verify:

1. Codex runs in a normal terminal session with sandboxing and auto-review.
2. SSH/browser disconnect and reconnect reach the same process.
3. Dashboard stop/start preserves the tmux session.
4. `codex resume` recovers the conversation after a deliberate stop.
5. Another device can open the redacted Funnel hostname and authenticate.
6. Public IPv4 and IPv6 connections to TCP 8080 fail.
7. Funnel can be disabled immediately.
8. Logout persistence works. Reboot testing requires separate approval.

## Managed and local paths

Repository-managed:

```text
~/dotfiles/nix/modules/home/aoe-dashboard.nix
~/dotfiles/nix/shared/vars.nix
~/dotfiles/setup/aoe-remote/
~/dotfiles/scripts/remote-dev/verify-aoe.sh
~/dotfiles/docs/remote-codex-aoe.md
```

Machine-local and never committed:

```text
~/.config/aoe-dashboard/serve.env
~/.local/state/aoe-dashboard/last-dashboard-boot-id
~/.codex/config.toml
~/.codex/auth.json
~/.config/agent-of-empires/config.toml
~/.config/agent-of-empires/serve.passphrase
AoE session, login, URL-token, and tmux state
```

AoE creates `serve.passphrase` with owner-only permissions while the dashboard
is running and removes it during a graceful shutdown. It is an application
runtime copy used by AoE's local TUI/restart flow; never commit or print it.

## Current official references

- [AoE remote phone access](https://www.agent-of-empires.com/guides/remote-phone-access/)
- [AoE Tailscale setup](https://www.agent-of-empires.com/guides/tailscale/)
- [AoE Git worktrees](https://www.agent-of-empires.com/guides/worktrees/)
- [AoE web dashboard](https://www.agent-of-empires.com/guides/web-dashboard/)
- [Codex CLI developer commands](https://learn.chatgpt.com/docs/developer-commands?surface=cli)
- [Tailscale Funnel](https://tailscale.com/kb/1223/funnel/)
- [Tailscale CLI operator setting](https://tailscale.com/kb/1080/cli/#operator)
