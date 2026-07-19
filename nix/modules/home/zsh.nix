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
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/.bun/bin"
  ];
}
