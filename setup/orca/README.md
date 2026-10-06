# Orca on remote-dev

Orca runs continuously on the VM as your normal user. Its desktop application
is a graphical client; the bundled `orca-ide` command is the Linux CLI. Desktop,
browser, and mobile clients can connect to the same VM-owned repositories,
worktrees, terminals, and agents over Tailscale. Agent of Empires remains available.

Codex is the default. Claude Code is installed and ready for later use, but
**Claude login and a Claude subscription are optional**. Missing or expired
Claude credentials do not block the service or Codex. Authenticate Claude only
when you intend to use it.

Agent CLI pins live in `../aoe-remote/codex-release.json` (official Codex user
installer) and `../claude-code/release.json` (Nix-managed Claude Code).
Shared instruction and Claude permission settings live in `../agent-config/`.

## Install

From the dotfiles root:

```bash
setup/orca/install.sh
setup/agent-skills/install-orca-cli.sh
scripts/remote-dev/rebuild.sh
systemctl --user start orca-runtime.service
setup/orca/configure.sh
scripts/remote-dev/verify-orca.sh
```

The installer downloads the version and architecture-specific checksum in
`release.json`, verifies the AppImage, extracts it without FUSE, and checks the
bundled CLI version before switching `current`. Reruns preserve the selected
release; old releases remain available. It installs neither a service nor
credentials, and never starts or restarts Orca. To reuse a download:

```bash
setup/orca/install.sh --archive /path/to/orca-linux.AppImage
```

The portable installer supports Linux x86_64 and aarch64. Fedora and other
non-Nix Linux machines need Electron's runtime libraries installed separately;
see the [upstream prerequisites](https://github.com/stablyai/orca/blob/v1.4.220/docs/reference/headless-linux-server.md).
The NixOS VM already provides those libraries through `nix-ld`. Service management
in this guide is specific to remote-dev's Home Manager configuration.

`ORCA_INSTALL_ROOT` and `ORCA_BIN_DIR` override the install destinations for
standalone installations and tests. The VM service deliberately uses the standard
user-local destination. `--release-file PATH` selects reviewed metadata for an
intentional upgrade; it does not discover or install a floating latest version.

## Defaults and agent accounts

`configure.sh` applies the following choices through the running local runtime's
authenticated settings API. Run it once after initial startup. It is not run on
every service restart, so later changes made in Orca stay yours. Rerunning it
intentionally resets these agent defaults:

| Setting | Value |
| --- | --- |
| Default agent | Codex |
| Codex and Claude | Enabled |
| Codex/Claude launch arguments | Empty: Orca's Manual mode |
| Agent status hooks | Enabled |
| Telemetry | Disabled by the service environment |

The helper uses the pinned release's bundled RPC client and never rewrites the
Orca profile database. It preserves other agents' arguments and settings.

Use Codex's existing **System default** account. Its model, profiles, MCP servers,
sandbox, and automatic approval reviewer continue to come from Codex configuration.
The setup does not copy credentials into dotfiles or create another Codex account.

Orca's Manual mode supplies no permission-bypass flag to normal terminal agents.
Each agent follows its own settings, including a later change to full access/Yolo
inside that agent. Codex's `approvals_reviewer = "auto_review"` is independent:
it can approve or deny eligible sandbox escalations while Manual is selected.
Orca's optional **native Chat UI** explicitly applies Orca's permission policy;
its Manual mode does not simply inherit full access from Codex configuration.
Keep normal agent terminals selected initially.

When you have a Claude subscription, run `claude` on the VM and complete its
normal account login. Choose Claude in Orca when needed. Leave Codex as the
default during periods without a subscription. Additional Orca-managed accounts
are optional; the host-local `orca-ide account add --agent claude` flow is for
adding one deliberately. Nothing in installation or verification requires it.

## Pair desktop, browser, and mobile clients

Keep each device connected to the same Tailscale network. The runtime advertises
the VM's current Tailscale IPv4 address on TCP 6768. Its upstream listener binds
all interfaces; the NixOS firewall permits this port only on `tailscale0`.
There is no new Funnel or public web endpoint.

Pair clients before starting agent work. The pairing helper restarts the runtime
to request a fresh offer. Connected clients briefly disconnect and reconnect.
Live terminals survive only when their daemon is in its separate systemd user
scope; see the restart verification below before relying on this during work.

### Desktop

Install the [Orca desktop app](https://github.com/stablyai/orca/releases/tag/v1.4.220)
on your laptop, then generate a runtime offer in an SSH terminal on the VM:

```bash
setup/orca/pair.sh runtime
```

On the laptop, open **Settings → Remote Orca Servers → Add Server**, name it
`remote-dev`, and paste the `orca://pair` link. Connect and select this server;
use **Advanced → Active Server** when new server-routed work should default to it.

### Browser

Generate another runtime offer for the browser with the same command. Open the
printed HTTP browser URL, which contains the pairing information. Pair each
client separately; do not rely on reusing a consumed offer. The URL is private
access material, so keep it out of commits, issues, screenshots, and shared logs.

### Mobile

Install Orca Mobile on the phone, connect Tailscale, and run:

```bash
setup/orca/pair.sh mobile
```

Choose **Pair** in Orca Mobile and scan the terminal QR or paste the mobile link.
This uses the VM directly through Tailscale. It does not require Orca Relay.
The helper always clears its temporary `ORCA_PAIRING_SCOPE` environment override;
future ordinary service restarts return to runtime offers. Previously paired
desktop/browser clients retain their grants.

Use **Shared Server Access** to revoke desktop/browser grants and the paired
mobile-device controls to revoke a phone. Test revocation with a spare grant,
not your only working client. Upstream headless mode currently does **not** send
background agent-completion push notifications, although mobile interaction works.

## Projects and optional orca.yaml

Add repositories already on the VM through the connected client or:

```bash
orca-ide repo add --path /absolute/path/to/repository --json
```

Use Orca's `~/orca/workspaces` workspace location, outside dotfiles, and set each
repository's base branch before creating worktrees. Repository credentials and
toolchains must be available on the VM. Existing Codex profiles can still be
launched from an Orca terminal, for example `codex --profile own`.

`setup/orca/configure.sh` also upserts eight Global Quick Commands on the VM:
**Codex · Default**, **Codex · OWN**, **Codex · SEO**, and **Codex · Sentry**.
The matching **Claude** commands run `claude-profile default|own|seo|sentry`.
Use the tab-bar Quick Commands menu to launch one in a fresh terminal in the
selected workspace. They run `codex` or `codex --profile <name>` and therefore
use the VM's native Codex configuration overlays. They do not switch an already
running agent's profile or affect ordinary Codex launches. Commands entered
through a terminal's context menu are inserted into that terminal instead;
use a fresh shell, not an agent prompt. Other saved commands are preserved.
Their **Saved on** host is the VM, so paired desktop/mobile clients can access
them. Codex uses native profiles; Claude uses generated settings/MCP overlays
and native plugins. See [shared agent setup](../agent-config/README.md).

## Chat UI

No dotfiles change is required to use terminal-backed Chat UI. On desktop,
choose Settings → Experimental → Chat UI and optionally make it the default
view. On mobile, choose Settings → Chat UI → Open sessions in Chat UI; the
preference is per device. Remote/SSH sessions use terminal-backed Chat UI.
The separate updated structured native chat is for eligible local sessions.
These profile shortcuts launch terminal agents and can be viewed through the
terminal-backed chat surface.

No `orca.yaml` is required. For a pnpm application, an optional repository-root
configuration could be:

```yaml
scripts:
  setup: pnpm install --frozen-lockfile
setupAgentStartupPolicy: wait-for-setup
defaultTabs:
  - title: Agent
  - title: Shell
```

Adapt the setup command to that repository's declared tooling. Configure whether
setup runs in **Settings → Repository**. Do not put global installers or NixOS
rebuilds in a worktree setup hook. Keep `.env` files and credentials ignored;
shared directories and `.worktreeinclude` are project-specific opt-ins.

## Operations and verification

```bash
systemctl --user status orca-runtime.service orca-virtual-display.service
orca-ide status --json
systemctl --user stop orca-runtime.service
systemctl --user start orca-runtime.service
journalctl --user -u orca-runtime.service
journalctl --user "_PID=$(systemctl --user show orca-runtime.service -p MainPID --value)"
scripts/remote-dev/verify-orca.sh
REMOTE_DEV_VERIFY_ORCA=1 scripts/remote-dev/verify-remote.sh
```

Electron attributes runtime output to its own app scope; the PID-filtered command
shows that output, while the service journal shows lifecycle events.
The runtime journal contains startup pairing offers. Inspect it locally; redact those
offers before sharing diagnostics. `verify-orca.sh` never prints account tokens
or requires Claude authentication.

The dedicated display is `:100`; Figma stays on `:99`. The runtime uses a bounded
restart policy and does not retry exit status 3 (another instance owns its profile).
After fixing a permanent startup failure, use `systemctl --user reset-failed
orca-runtime.service` before starting it again.

For acceptance, connect all three clients, create a disposable repository/worktree,
launch Codex, and verify its normal sandbox/auto-review behavior. Disconnect a
client and confirm its session survives. Before testing an Orca service restart,
check the terminal daemon's `cgroupUnit` health field or match its PID to an
`orca-daemon-*.scope` unit. An unscoped daemon can lose its terminals on restart.
Test with a disposable shell first. A VM reboot restarts Orca and restores
persisted state; it does not preserve running operating-system processes.

Claude's unauthenticated CLI version check is sufficient for initial acceptance.
An authenticated Claude session test is deferred until you choose to log in.
Also verify Figma can start alongside Orca, AoE remains available, and port 6768
is reachable over Tailscale but blocked on public interfaces.

Validated on remote-dev with v1.4.220: browser pairing over the Tailscale address,
browser reconnection, mobile offer generation, and a disposable shell retaining
the same PID across a runtime restart. Codex and Claude version checks passed
inside that terminal. Figma and Orca ran together on their separate displays;
AoE stayed active. Actual laptop/phone pairing, agent inference, and a connection
attempt from outside the tailnet remain device-side acceptance checks.

## Updates and rollback

Orca does not auto-update in `serve` mode. Review a release, update `release.json`
with its tag and published SHA-256 values, and run the installer tests. Match the
client version to the server when diagnosing protocol compatibility problems.

Before changing the active release, stop agent work and Orca, then make an
owner-only backup of both `~/.config/orca` and `~/.config/Orca` when present.
These contain settings, profile databases, account/pairing material, and history.
Keep the backup outside dotfiles. Include any SQLite sidecars by archiving the
whole stopped profile directories. The installer retains old release directories
but does not back up or downgrade profile schemas.

Run `install.sh`, start the service, and run `verify-orca.sh`. If rollback is
needed, stop the service, retain the failed version's profile separately, restore
the matching profile backup, and run the installer with the previous release's
metadata. Then restart and verify. Do not restore an old binary over a migrated
profile without its matching backup. Claude updates through the Nix flake.

Persistent locations:

- `~/.local/share/orca-install/releases/<version>` and `current`: application files.
- `~/.local/bin/orca-ide`: bundled CLI link; Orca may also maintain its own `orca` shim.
- `~/.config/orca` / `~/.config/Orca`: application-owned runtime state.
- `~/.config/orca-runtime/Xauthority`: private virtual-display cookie.
- `~/orca/workspaces`: worktrees, independent of the installation.

To disable the baseline, set `orcaRuntime.enable = false` and rebuild. This closes
the Orca firewall port and removes its services without deleting your profiles or
worktrees. AoE can continue to keep user lingering enabled.
