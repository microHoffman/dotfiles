{ pkgs, vars, ... }:
{
  services.ssh-agent.enable = true;

  # ssh-agent does not always remove its Unix socket after an abrupt stop. A
  # stale socket prevents the managed service from starting after a rebuild.
  systemd.user.services.ssh-agent.Service.ExecStartPre = "${pkgs.coreutils}/bin/rm -f %t/ssh-agent";

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        ServerAliveInterval = 30;
        ServerAliveCountMax = 3;
      };
      "github.com" = {
        IdentityFile = "${vars.homeDirectory}/.ssh/id_ed25519_remote_dev";
        IdentitiesOnly = true;
      };
      "gitlab.com" = {
        IdentityFile = "${vars.homeDirectory}/.ssh/id_ed25519_remote_dev";
        IdentitiesOnly = true;
      };
    };
  };
}
