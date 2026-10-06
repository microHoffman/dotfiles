{ lib, vars, ... }:
{
  networking.firewall = {
    enable = true;
    allowPing = true;
    interfaces.tailscale0.allowedTCPPorts = lib.optionals vars.orcaRuntime.enable [
      vars.orcaRuntime.port
    ];
  };
}
