{
  description = "Personal dotfiles and NixOS remote development workstation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      disko,
      ...
    }:
    let
      system = "x86_64-linux";
      vars = import ./shared/vars.nix;
      pkgs = nixpkgs.legacyPackages.${system};
      agentConfigReconciler = pkgs.callPackage ./packages/agent-config-reconciler.nix { };
    in
    {
      nixosConfigurations.remote-dev = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs vars;
        };
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          ./hosts/remote-dev
        ];
      };

      checks.${system}.agent-config-reconciler =
        pkgs.runCommand "agent-config-reconciler-check"
          {
            nativeBuildInputs = [
              agentConfigReconciler
              pkgs.coreutils
              pkgs.python3
              pkgs.util-linux
            ];
          }
          ''
            bash ${../setup/aoe-remote/test-reconcile-config.sh} ${pkgs.lib.getExe agentConfigReconciler}
            touch "$out"
          '';

      formatter.${system} = pkgs.nixfmt;
    };
}
