# Foundry setup

This installs global Foundry RPC aliases backed by public dRPC endpoints. No
default network is selected, so every live-chain command must name an alias
explicitly:

```bash
cast chain-id --rpc-url celo_sepolia_drpc
cast block-number --rpc-url ethereum_drpc
```

Use `--celo` in addition to the RPC alias when a command needs Celo-specific
transaction handling. Regular read-only RPC calls do not need it.

The endpoints are public and may be rate-limited. Do not put private keys,
keystore passwords, or API tokens in `foundry.toml`; use Foundry's encrypted
keystores or environment variables instead.

## Portable installation

On a machine not managed by this repository's Home Manager configuration, run:

```bash
setup/foundry/install.sh
```

Set `FOUNDRY_INSTALL_DIR` to install into a different directory. The installer
only updates `foundry.toml` and does not modify the `keystores` directory.

The `remote-dev` NixOS host installs this file through Home Manager, so the
portable installer is not needed there.
