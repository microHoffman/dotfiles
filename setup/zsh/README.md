# Local workstation zsh setup

This setup installs zsh helpers that should exist only on the local workstation.
It is not imported by the `remote-dev` NixOS/Home Manager configuration.

From the dotfiles repository on the local PC, run:

```bash
setup/zsh/install.sh
```

The installer adds an idempotent managed block to `~/.zshrc` that sources
`local-workstation.zsh`. Open a new shell or reload the configuration:

```zsh
source ~/.zshrc
```

## Shopty preview tunnel

Start the tunnel:

```zsh
shopty-tunnel
```

The command uses `sudo` only because binding local port 80 requires elevated
privileges. It forwards `127.0.0.1:80` on the local PC to `127.0.0.1:80` on
`remote-dev`. While it is running, preview Shopty at:

<http://127.0.0.1/>

Stop the tunnel with `Ctrl+C`.

The alias expects:

- a local SSH host named `remote-dev`
- the local identity at `~/.ssh/id_ed25519`
- the local known-hosts file at `~/.ssh/known_hosts`

To test the installer without editing the real zsh configuration:

```bash
ZSHRC_PATH=/tmp/test-zshrc setup/zsh/install.sh
```
