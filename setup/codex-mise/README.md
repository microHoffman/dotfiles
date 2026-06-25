# Codex mise setup

This setup makes mise-managed tools such as `node`, `npm`, and `npx`
available inside Codex shell commands.

For normal interactive shells, use the shell-specific `mise activate`
configuration recommended by mise. For Codex command execution, this setup only
adds the mise shims directory to `PATH` when Codex environment variables are
present. That keeps `~/.zshenv` lightweight while allowing mise shims to resolve
project-local versions from `mise.toml`, `.mise.toml`, `.node-version`, and
global mise config.

Run:

```bash
setup/codex-mise/install.sh
```

The installer updates `~/.zshenv` idempotently. To target a different file for
testing, set `ZSHENV_PATH`:

```bash
ZSHENV_PATH=/tmp/test-zshenv setup/codex-mise/install.sh
```

Verify:

```bash
CODEX_THREAD_ID=test zsh -c 'command -v node; node -v; command -v npm; npm -v'
```

For regular Agent of Empires Codex sessions, this covers commands that Codex
runs after it starts. It does not configure AOE cockpit startup; for cockpit,
use `AOE_COCKPIT_NODE` or start `aoe serve` with the mise shims on `PATH`.
