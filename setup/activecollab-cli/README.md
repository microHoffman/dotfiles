# ActiveCollab CLI setup

Install the pinned default release globally through mise:

```bash
setup/activecollab-cli/install.sh
```

Override the version for a single installation:

```bash
ACTIVECOLLAB_CLI_VERSION=0.3.0 setup/activecollab-cli/install.sh
```

The installer does not manage credentials. Log in interactively afterward:

```bash
activecollab auth login --url https://activecollab.example.com/api/v1
```

The CLI saves the URL, account, and token in its protected per-user credentials
file. For CI or ephemeral sessions, `ACTIVECOLLAB_URL` and
`ACTIVECOLLAB_TOKEN` can be supplied through a protected environment instead.
Never commit either value to this repository.

Installation without mise is documented in the
[`activecollab-cli` installation guide](https://github.com/microHoffman/activecollab-cli/blob/main/docs/installation.md).
