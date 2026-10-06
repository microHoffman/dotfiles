# Shared agent configuration

`AGENTS.md` is the common global instruction source. Home Manager links it to
`~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md`. Edit this source rather than
installed skills when changing personal policy. Its browser routing explicitly
overrides the broad preference in the upstream agent-browser skill: Orca's
embedded browser for Orca workspaces, standalone agent-browser for external
browser/Electron targets and work outside Orca, and project Playwright for E2E.

`claude-settings.json` is merged into the mutable `~/.claude/settings.json`.
Orca hooks, statusLine, permission rules, and other unrelated settings survive.
It selects `permissions.defaultMode = auto` (classifier-based approvals) and
enables both project `CLAUDE.md` and `AGENTS.md` via Claude's built-in plugin.
Auto mode still depends on account/model/organization availability; no login
is needed to install the configuration. It does not grant bypass permissions
or enable Claude's separate sandbox feature.

Native project AGENTS.md support requires Claude Code 2.1.277+, and this plugin
ID requires 2.1.285+. The pinned release is newer. The global Claude file is
still named `CLAUDE.md`; it is not a second maintained copy of the instructions.
Run `/context` in a fresh Claude session to inspect loaded instruction files.

Outside Nix, use the same source at the two user-wide instruction paths and
merge the settings with the portable reconciler (Python 3.11+ and tomlkit):

```bash
python3 setup/aoe-remote/reconcile_config.py --format json \
  --source setup/agent-config/claude-settings.json \
  --target "$HOME/.claude/settings.json" \
  --lock "$HOME/.claude/settings.json.lock"
```

## MCP and launch presets

The MCP blocks in `../aoe-remote/codex-config.toml` and `own.config.toml` are
the canonical endpoint definitions for both harnesses. `render-claude.py`
adapts them into Claude JSON during the Nix build (or portable setup):

- OpenAI developer docs and hosted GitHits are merged into `~/.claude.json`.
- OWN's Notion, Figma, and OWN context servers are loaded only by the OWN
  preset. Public OAuth client ID, requested scopes, and callback port are
  translated into Claude's field names. Credentials stay separate per harness.
- Sentry's MCP server and skills come from the official plugin in each
  harness. Claude uses `getsentry/plugin-claude`; Codex uses `plugin-codex`.
- SEO uses the native suite for each harness. Claude's plugin and Codex's
  port have their own releases, agents, and optional integrations.

The Nix rebuild installs `claude-profile` and the generated preset files.
Use `claude-profile default|own|seo|sentry`, or the matching Orca Quick Command.
Arguments such as `--model opus` are forwarded. Settings files enable only the
matching SEO/Sentry plugin from this pair. Other user/project settings and MCP
servers continue to apply; these are overlays, not isolation boundaries.
Plain `claude` uses the common configuration without either optional plugin.

For portable setup, run `setup/agent-config/configure-claude.sh` (Python 3.11+
and tomlkit) and `setup/agent-skills/install-claude-plugins.sh`. Nix applies the
configuration offline; plugin downloads remain an explicit setup step.
The plugin installer also prepares SEO's isolated Python/Chromium runtime in
`~/.local/share/claude-seo` (or XDG data home). The SEO preset selects that
runtime and supplies NixOS browser libraries where available. Run `/seo doctor`
in the preset to check it; `/seo setup` refreshes it. The standalone
`setup/agent-skills/setup-claude-seo.sh` performs the same setup without an
authenticated Claude session.

Claude login stays optional. When you start using it, authenticate each
protected MCP server from `/mcp` in the relevant preset. Codex OAuth tokens are
not copied. The local Figma server still needs to be running for its tools.
Shared instructions retain explicit human confirmation for Notion/Figma writes;
Codex-specific tool approval settings are not portable permission enforcement.

References: [Claude memory](https://code.claude.com/docs/en/memory),
[permission modes](https://code.claude.com/docs/en/permission-modes).
