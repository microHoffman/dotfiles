# Local-workstation-only shell helpers.
#
# This file is sourced by ~/.zshrc after running setup/zsh/install.sh. It is
# intentionally not imported by the remote-dev Home Manager configuration.

alias shopty-tunnel='sudo env SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ssh -F "$HOME/.ssh/config" -i "$HOME/.ssh/id_ed25519" -o UserKnownHostsFile="$HOME/.ssh/known_hosts" -o IdentitiesOnly=yes -o ExitOnForwardFailure=yes -N -L 127.0.0.1:80:127.0.0.1:80 microhoffman@remote-dev'
