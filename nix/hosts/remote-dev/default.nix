{
  lib,
  pkgs,
  vars,
  ...
}:
{
  imports = [
    ./hardware.nix
    ./disko.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/users.nix
    ../../modules/nixos/workdirs.nix
    ../../modules/nixos/firewall.nix
    ../../modules/nixos/ssh.nix
    ../../modules/nixos/tailscale.nix
    ../../modules/nixos/docker.nix
    ../../modules/nixos/nix-ld.nix
    ../../modules/nixos/zram.nix
  ];

  networking.hostName = "remote-dev";
  time.timeZone = vars.timeZone;
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    trusted-users = [
      "root"
      "@wheel"
    ];
  };

  nixpkgs.config.allowUnfree = true;
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    curl
    file
    git
    htop
    lsof
    neovim
    pciutils
    tmux
    usbutils
    vim
    wget
  ];

  services.fstrim.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit vars;
    };
    users.${vars.username} = {
      imports = [
        ../../modules/home/dev-tools.nix
        ../../modules/home/git.nix
        ../../modules/home/neovim.nix
        ../../modules/home/ssh-agent.nix
        ../../modules/home/tmux.nix
        ../../modules/home/zsh.nix
      ];

      home = {
        username = vars.username;
        homeDirectory = vars.homeDirectory;
        stateVersion = vars.homeStateVersion;
      };

      programs.home-manager.enable = true;
    };
  };

  system.stateVersion = vars.systemStateVersion;
}
