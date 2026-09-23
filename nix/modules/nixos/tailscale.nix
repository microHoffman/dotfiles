{
    config,
    inputs,
    lib,
    pkgs,
    vars,
    ...
  }:
  {
    services.tailscale = {
      enable = true;
      package =
        inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.tailscale;

      extraSetFlags = lib.optionals vars.aoeDashboard.enableTailscaleOperator [
        "--operator=${vars.username}"
      ];
    };

    networking.firewall.allowedUDPPorts = [
      config.services.tailscale.port
    ];
  }

