## Agent skills

This dotfiles repo installs personal agent skills by reference. The skill source
code lives in its own repository; this repo only keeps the setup entrypoint.
Local source checkouts for development live under `~/myrepos`; dotfiles installs
published skills with `npx skills add`.

| Skill | Repository | Installer |
| --- | --- | --- |
| `gitlab-create-mr` | https://github.com/microHoffman/agent-skills | `setup/agent-skills/install-gitlab-create-mr.sh` |

## Useful guides

### remote dev server

Planning/runbook for the NixOS remote workstation lives in
[`docs/remote-dev-server.md`](docs/remote-dev-server.md).
Implementation handoff for the next session lives in
[`docs/remote-dev-implementation-handoff.md`](docs/remote-dev-implementation-handoff.md).

### ssh-agent setup on hyprland

https://www.lorenzobettini.it/2023/09/hyprland-and-ssh-agent/
