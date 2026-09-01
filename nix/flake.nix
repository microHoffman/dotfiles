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

    # v0.17.0's tag still points its Nix package at 0.16.0. Pin the upstream
    # post-release flake update that carries the 0.17.0 binary and hash.
    figma-linux-next = {
      url = "github:arximus88/figma-linux-next/5b0877078e2c95be053c07dd3534613ad73bab6f";
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

      checks.${system} = {
        codex-acp-installer =
          pkgs.runCommand "codex-acp-installer-check"
            {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.coreutils
                pkgs.gnugrep
              ];
            }
            ''
              bash ${../setup/codex-acp/test-install.sh} ${../setup/codex-acp/install.sh}
              touch "$out"
            '';

        agent-config-reconciler =
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

        agent-skill-installers =
          pkgs.runCommand "agent-skill-installers-check"
            {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.coreutils
                pkgs.gnugrep
                pkgs.gnused
                pkgs.python3
              ];
            }
            ''
              bash ${../setup/agent-skills/test-installers.sh} ${../setup/agent-skills}
              touch "$out"
            '';
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
