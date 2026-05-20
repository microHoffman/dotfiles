{ lib, pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    clock24 = true;
    escapeTime = 10;
    focusEvents = true;
    historyLimit = 100000;
    keyMode = "vi";
    mouse = true;
    secureSocket = false;
    sensibleOnTop = true;
    terminal = "tmux-256color";
    plugins = [
      {
        plugin = pkgs.tmuxPlugins.resurrect;
        extraConfig = ''
          set -g @resurrect-dir '~/.local/share/tmux/resurrect'
          set -g @resurrect-processes 'false'
          set -g @resurrect-strategy-nvim 'session'
        '';
      }
    ];
    extraConfig = ''
      set -g status-position bottom
      set -g status-style "bg=colour235,fg=colour248"
      set -g set-clipboard on
      set -g allow-passthrough on
      set -ga terminal-overrides ",xterm-256color:Tc,tmux-256color:Tc"
    '';
  };

  home.activation.createTmuxResurrectDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.local/share/tmux/resurrect"
  '';
}
