{
  config,
  lib,
  vars,
  ...
}:
{
  services.tailscale = {
    enable = true;
    extraSetFlags = lib.optionals vars.aoeDashboard.enableTailscaleOperator [
      "--operator=${vars.username}"
    ];
  };

  networking.firewall.allowedUDPPorts = [
    config.services.tailscale.port
  ];
}
