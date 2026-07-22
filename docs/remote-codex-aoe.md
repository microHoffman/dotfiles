# Remote Codex and Agent of Empires Runbook

This runbook adds a persistent personal Codex environment to the NixOS
`remote-dev` host. Normal OpenSSH runs over Tailscale. Agent of Empires manages
terminal-based Codex processes in tmux and publishes only its loopback web
dashboard through Tailscale Funnel.

The configuration is intentionally staged. Start a new host with these values
set to `false` in `nix/shared/vars.nix`:

```nix
aoeDashboard = {
  enable = false;
  enableTailscaleOperator = false;
  enableUserLinger = false;
};
```

Do not enable them until their approval steps below are complete. The finalized
personal host sets all three to `true`; Nix evaluation rejects `enable = true`
unless both prerequisite gates are also enabled.

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
- AoE owns session lifecycle and recovery. After a reboot it automatically
  recovers eligible terminal sessions with stored conversation IDs. It leaves
  archived, snoozed, trashed, explicitly stopped, structured, and non-resumable
  sessions alone. There is no separate repository-maintained recovery layer.

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
already has configuration on a non-Nix machine. On the NixOS `remote-dev` host,
Home Manager reconciles every repository-owned value from the two templates
into the live files during activation. Repository tables are deep-merged,
repository scalars and arrays win, and application-generated keys not present
in the templates are preserved. Template key removal is intentionally not a
live-key deletion mechanism; use a separately reviewed migration for removals.

Authenticate Codex interactively on the headless server:

```bash
codex login --device-auth
codex login status
```

The default Codex configuration keeps Sentry disabled. The dedicated Sentry
profile enables Sentry's complete official Codex plugin, including its bundled
skills and hosted MCP. Install the global tooling and authenticate within that
profile:

```bash
setup/agent-skills/install-all-global.sh
codex --profile sentry mcp login sentry
```

The plugin preserves Sentry's own per-skill invocation policies. The deprecated
standalone `sentry-fix-issues` skill and the dotfiles-maintained explicit-only
wrapper are removed.

Install global skills, repository-scoped skills, and GitHits using the commands
in [`setup/aoe-remote/README.md`](../setup/aoe-remote/README.md). The `seo`,
`own`, and `sentry` AoE profiles select their matching Codex profiles:

```bash
aoe -p seo
aoe -p own
aoe -p sentry
```

Sentry tmux sessions receive the complete plugin. ACP sessions currently
receive the profile-local Sentry MCP but not the Codex profile's plugin skills.

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

Effect: `microhoffman` can manage this node's Tailscale daemon. This is expected
for the single-user host. To undo it durably, first stop the dashboard, set both
`aoeDashboard.enable = false` and `enableTailscaleOperator = false`, and rebuild.
Then run `sudo tailscale set --operator=root`. This does not interrupt SSH.

## Phase 5: Funnel exposure approval

Before enabling Funnel, display the resolved values and obtain confirmation:

- Public URL: `https://<machine>.<tailnet>.ts.net` on HTTPS 443.
- Destination: only `127.0.0.1:8080` on the VPS.
- Public content: the AoE login page. A first login requires both the URL token
  and passphrase.
- Risk: an authenticated dashboard provides terminal input as `microhoffman`.
  Because this personal account has passwordless sudo and Docker access, treat
  dashboard compromise as full root compromise. This setup intentionally keeps
  one account for simplicity instead of maintaining a separate dashboard user.
- Metadata: the machine and tailnet DNS names appear in the public hostname.

Read the server's Tailscale IP, enable Funnel in the
[Funnel admin page](https://login.tailscale.com/f/funnel), then open the
[policy editor](https://login.tailscale.com/admin/acls/file):

```bash
tailscale ip -4
```

Merge a least-privilege node attribute into the existing policy, targeting only
that server IP:

```json
"nodeAttrs": [
  {
    "target": ["<SERVER_TAILSCALE_IP>"],
    "attr": ["funnel"]
  }
]
```

Never replace the rest of the policy. If Funnel setup already added a rule for
`autogroup:member`, replace only that rule's target with the server IP. Do not
append the narrower rule while retaining `autogroup:member`, because the broad
grant would still apply to every personal tailnet device. Verify:

```bash
tailscale status
tailscale funnel status
```

To disable public transport immediately, stop the dashboard and remove its
current mapping:

```bash
systemctl --user stop aoe-dashboard
tailscale funnel --https=443 off
tailscale funnel status
```

This remains off until the dashboard service starts again. For durable shutdown,
also set `aoeDashboard.enable = false`, rebuild, and confirm the service is no
longer enabled before the next reboot. The check
`systemctl --user is-enabled aoe-dashboard` should report `disabled` or
`not-found`. The operator and linger gates may remain enabled if you expect to
turn the dashboard back on later.

Run `tailscale funnel status` before considering `tailscale funnel reset`;
`reset` removes every Funnel mapping on the node.

## Phase 6: passphrase, lingering, and dashboard

Generate at least 24 random characters in a password manager. Store it through
the hidden prompt, never as a shell argument:

```bash
setup/aoe-remote/set-passphrase.sh
```

This creates `~/.config/aoe-dashboard/serve.env` in an owner-only directory with
mode `0600`. When the dashboard is already active, the script restarts it and
waits for `aoe serve --status` so the new passphrase and device invalidation
take effect immediately. If health verification fails, it stops the dashboard
and prints the Funnel-off command. It never starts an inactive dashboard.

Lingering lets the user systemd manager start at boot and continue after logout.
After its separate approval, set:

```nix
aoeDashboard.enableUserLinger = true;
```

This is the declarative equivalent of:

```bash
sudo loginctl enable-linger microhoffman
```

To undo lingering durably, first stop the dashboard, set both
`aoeDashboard.enable = false` and `enableUserLinger = false`, and rebuild. Then
run `sudo loginctl disable-linger microhoffman`. It does not affect SSH.

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

New sessions use the selected project checkout by default. When isolation for a
concurrent task is useful, opt into one outcome-oriented worktree session with
the new-session toggle or the explicit CLI flags:

```bash
aoe add /path/to/example \
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
aoe remove fix-refresh-token
```

AoE stops the session and moves its metadata and managed worktree to recoverable
trash. The baseline keeps trash for 30 days, then AoE automatically purges the
worktree and merged branch. Restore during that window with
`aoe session restore fix-refresh-token`. Avoid `--force` and `--purge` during
normal operation; use an explicit purge only when immediate irreversible cleanup
is worth losing the recovery window.

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
4. Open the installed PWA, then under **Settings > Notifications** enable
   notifications, grant Android permission, and send a test notification.
5. Review or revoke devices under **Settings > Web Dashboard > Connected
   Devices**.
6. Optionally disconnect Tailscale on Android and reload the PWA once to verify
   that Funnel works over the public internet, then reconnect Tailscale.

The Funnel PWA does not require the Tailscale Android app. Full SSH does:

1. Install Tailscale Android and join the same tailnet.
2. Generate a dedicated Ed25519 key in an Android SSH client.
3. Add only its public key to `authorizedSshKeys` and rebuild.
4. Connect to `microhoffman@<tailscale-magicdns-name>`.

If the phone is lost, remove it from the tailnet, remove its SSH public key and
rebuild, revoke its AoE dashboard device, and run `set-passphrase.sh` to rotate
the passphrase and restart the active dashboard immediately.

## Three persistence layers

- **Live process persistence:** tmux/AoE keeps Codex alive across laptop,
  browser, SSH, and network disconnects. Live processes do not survive a host
  reboot.
- **Conversation persistence:** `codex resume` reloads a stored conversation
  after the process has ended or the server has rebooted.
- **Code persistence:** worktree files and branches persist on disk. Commits and
  remote pushes are the durable recovery boundary.

After reboot, the dashboard returns through systemd and lingering. AoE
automatically recovers only sessions it considers eligible; sessions you
archived, snoozed, trashed, or explicitly stopped remain inactive. Inspect the
result with:

```bash
aoe list
tmux list-sessions
git -C <main-checkout> worktree list
git -C <worktree> status
```

If an eligible session cannot be recovered, enter its worktree and use:

```bash
codex resume --last
```

tmux-resurrect remains manual and does not automatically restore Codex agents.

For a controlled reboot test, first commit or preserve all work, explicitly stop
any agent that must remain inactive, and keep the provider console available.
Display the impact and obtain approval before running:

```bash
sudo systemctl reboot
```

SSH and all live processes disconnect. After the host returns, reconnect over
Tailscale, run both verification scripts below, open the existing PWA URL, and
confirm explicitly stopped AoE sessions remain inactive. The SSH agent starts
empty after a reboot, so restore remote Git access interactively:

```bash
ssh-add ~/.ssh/id_ed25519_remote_dev
ssh -T git@github.com
```

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
stop-plus-Funnel-off sequence above for emergency shutdown, and disable the
declarative dashboard gate for durable shutdown.

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

After every acceptance check passes, permanently remove only the known
disposable session when immediate cleanup is intended. Show the exact target and
obtain confirmation because this bypasses the normal 30-day trash recovery:

```bash
aoe remove <test-session> --purge --delete-worktree --delete-branch --force
```

Verify the AoE row, tmux session, worktree, and test branch are absent before
removing the disposable main repository by its exact path.

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
~/.config/systemd/user/aoe-dashboard.service
~/.config/aoe-dashboard/serve.env
~/.codex/config.toml
~/.codex/auth.json
~/.config/agent-of-empires/config.toml
~/.config/agent-of-empires/login_sessions.toml
~/.config/agent-of-empires/push.vapid.json
~/.config/agent-of-empires/serve.url
~/.config/agent-of-empires/serve.token
~/.config/agent-of-empires/serve.passphrase
~/.config/agent-of-empires/serve.saved_passphrase
~/.config/agent-of-empires/serve.mode
~/.config/agent-of-empires/serve.pid
~/.config/agent-of-empires/profiles/*/sessions.json
AoE database, session, plugin, and tmux state
```

The two live application config files remain machine-local and writable. Home
Manager only reconciles values declared in the repository templates; Codex and
AoE retain ownership of all other values and runtime state.

The systemd unit is a Home Manager-generated symlink. Dashboard credentials,
URL tokens, login sessions, and push keys are sensitive machine-local state;
never commit or print them. AoE creates `serve.passphrase` with owner-only
permissions while the dashboard is running and removes it during a graceful
shutdown.

## Current official references

- [AoE remote phone access](https://www.agent-of-empires.com/guides/remote-phone-access/)
- [AoE Tailscale setup](https://www.agent-of-empires.com/guides/tailscale/)
- [AoE Git worktrees](https://www.agent-of-empires.com/guides/worktrees/)
- [AoE web dashboard](https://www.agent-of-empires.com/guides/web-dashboard/)
- [AoE push notifications](https://www.agent-of-empires.com/docs/push-notifications/)
- [Codex CLI developer commands](https://learn.chatgpt.com/docs/developer-commands?surface=cli)
- [Tailscale Funnel](https://tailscale.com/docs/features/tailscale-funnel)
- [Tailscale CLI operator setting](https://tailscale.com/docs/reference/troubleshooting/linux/linux-operator-permission)
