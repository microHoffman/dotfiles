{
  description = "Personal dotfiles and NixOS remote development workstation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
