# Shared commands

Portable executable commands that should be available on both local and remote
machines live in this directory.

Install them on a non-NixOS workstation:

```bash
setup/commands/install.sh
```

The installer creates symlinks in `~/.local/bin` and refuses to replace a
regular file. Override the destination for testing with
`DOTFILES_COMMANDS_BIN_DIR`.

Remote-dev installs the same source files declaratively through Home Manager.

## Agent of Empires idle sessions

Preview idle tmux sessions with a runtime age of at least one day:

```bash
aoe-old-idle
```

Stop the matching sessions after previewing them and confirming:

```bash
aoe-old-idle --stop
```

The command accepts an age such as `2d`, `12h`, or `30m`. A bare integer is
interpreted as days:

```bash
aoe-old-idle 2d
aoe-old-idle --stop 2d
```

The age is the lifetime of the current AoE runtime, not the time since the last
interaction. Only sessions that are currently `idle` and use the `tmux`
substrate are selected. Running and waiting sessions are excluded.
