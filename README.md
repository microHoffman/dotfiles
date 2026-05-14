## Agent skills

This dotfiles repo installs personal agent skills by reference. The skill source
code lives in its own repository; this repo only keeps the setup entrypoint.
Local source checkouts for development live under `~/myrepos`; dotfiles installs
published skills with `npx skills add`.

| Skill | Repository | Installer |
| --- | --- | --- |
| `gitlab-create-mr` | https://github.com/microHoffman/agent-skills | `setup/agent-skills/install-gitlab-create-mr.sh` |

## Useful guides

### ssh-agent setup on hyprland

https://www.lorenzobettini.it/2023/09/hyprland-and-ssh-agent/
