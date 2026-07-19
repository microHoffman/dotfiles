{ vars, ... }:
{
  services.ssh-agent.enable = true;

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
