{ vars, ... }:
{
  programs.zsh = {
    enable = true;
    autocd = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      size = 100000;
      save = 100000;
      append = true;
      share = true;
      ignoreDups = true;
      ignoreAllDups = true;
      saveNoDups = true;
      findNoDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      extended = true;
    };
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [
        "git"
        "docker"
        "docker-compose"
        "sudo"
        "systemd"
        "fzf"
      ];
    };
    shellAliases = {
      ".." = "cd ..";
      gs = "git status --short --branch";
      ll = "eza -lah --git";
      rebuild-remote-dev = "${vars.dotfilesDirectory}/scripts/remote-dev/rebuild.sh";
    };
    initContent = ''
      setopt AUTO_PUSHD
      setopt PUSHD_IGNORE_DUPS
    '';
    envExtra = ''
      # Make mise-managed tools available to Codex command shells without full shell activation.
      if [[ -n "''${CODEX_THREAD_ID:-}" || -n "''${CODEX_SANDBOX:-}" || -n "''${CODEX_SANDBOX_NETWORK_DISABLED:-}" ]]; then
        mise_shims="''${MISE_SHIMS_DIR:-''${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims}"
        if [[ -d "$mise_shims" ]]; then
          typeset -U path
          path=("$HOME/.local/bin" "$mise_shims" $path)
          export PATH
        fi
      fi
    '';
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/.bun/bin"
  ];
}
