{ pkgs, vars, ... }:
{
  security.sudo.wheelNeedsPassword = false;
  users.mutableUsers = true;

  users.users.root.hashedPassword = "!";

  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.fullName;
    home = vars.homeDirectory;
    createHome = true;
    shell = pkgs.zsh;
    hashedPassword = "!";
    extraGroups = [
      "wheel"
      "docker"
    ];
    openssh.authorizedKeys.keys = vars.authorizedSshKeys;
  };
}
