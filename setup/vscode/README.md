# VS Code setup

This installs portable VS Code editor preferences that are useful on both local
Fedora workstations and remote development machines.

```bash
setup/vscode/install.sh
```

The installer:

- installs extensions listed in `extensions.txt`
- merges `settings.json` into the current VS Code user settings
- creates a timestamped backup before changing an existing settings file

The logging dimming rules use the `ufukty.dim` extension. They dim common
PHP/Symfony logger calls and TypeScript logger/console calls, including
multi-line calls that end with `);`.

Environment overrides:

- `CODE_BIN=code-insiders setup/vscode/install.sh`
- `VSCODE_USER_DIR=/path/to/User setup/vscode/install.sh`
