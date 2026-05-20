{ vars, ... }:
{
  services.ssh-agent.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        addKeysToAgent = "yes";
        serverAliveInterval = 30;
        serverAliveCountMax = 3;
      };
      "github.com" = {
        identityFile = "${vars.homeDirectory}/.ssh/id_ed25519_remote_dev";
        identitiesOnly = true;
      };
      "gitlab.com" = {
        identityFile = "${vars.homeDirectory}/.ssh/id_ed25519_remote_dev";
        identitiesOnly = true;
      };
    };
  };
}
