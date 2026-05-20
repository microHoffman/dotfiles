{ lib, vars, ... }:
{
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      AllowAgentForwarding = false;
      AllowUsers = [ vars.username ];
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };

  networking.firewall = {
    allowedTCPPorts = lib.optionals vars.allowPublicSsh [ 22 ];
    interfaces.tailscale0.allowedTCPPorts = [ 22 ];
  };
}
