{
  config,
  lib,
  pkgs,
  ...
}:
let
  reconciler = pkgs.callPackage ../../packages/agent-config-reconciler.nix { };
  codexTemplate = ../../../setup/aoe-remote/codex-config.toml;
  codexSeoTemplate = pkgs.writeText "codex-seo-config.toml" ''
    ${builtins.readFile ../../../setup/aoe-remote/seo.config.toml}

    [shell_environment_policy]
    set = { LD_LIBRARY_PATH = "/run/current-system/sw/share/nix-ld/lib" }
  '';
  codexOwnTemplate = ../../../setup/aoe-remote/own.config.toml;
  aoeTemplate = ../../../setup/aoe-remote/aoe-config.toml;
  aoeSeoTemplate = ../../../setup/aoe-remote/profiles/seo/config.toml;
  aoeOwnTemplate = ../../../setup/aoe-remote/profiles/own/config.toml;
  codexConfig = "${config.home.homeDirectory}/.codex/config.toml";
  codexSeoConfig = "${config.home.homeDirectory}/.codex/seo.config.toml";
  codexOwnConfig = "${config.home.homeDirectory}/.codex/own.config.toml";
  aoeConfig = "${config.xdg.configHome}/agent-of-empires/config.toml";
  aoeSeoConfig = "${config.xdg.configHome}/agent-of-empires/profiles/seo/config.toml";
  aoeOwnConfig = "${config.xdg.configHome}/agent-of-empires/profiles/own/config.toml";
in
{
  home.file.".codex/AGENTS.md" = {
    source = ../../../setup/agent-config/AGENTS.md;
    force = true;
  };

  home.activation.reconcileAgentConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${lib.getExe reconciler} \
      --source ${codexTemplate} \
      --target ${codexConfig} \
      --lock ${codexConfig}.lock

    $DRY_RUN_CMD ${lib.getExe reconciler} \
      --source ${codexSeoTemplate} \
      --target ${codexSeoConfig} \
      --lock ${codexSeoConfig}.lock

    $DRY_RUN_CMD ${lib.getExe reconciler} \
      --source ${codexOwnTemplate} \
      --target ${codexOwnConfig} \
      --lock ${codexOwnConfig}.lock

    $DRY_RUN_CMD ${lib.getExe reconciler} \
      --source ${aoeTemplate} \
      --target ${aoeConfig} \
      --lock ${config.xdg.configHome}/agent-of-empires/.config.lock

    $DRY_RUN_CMD ${lib.getExe reconciler} \
      --source ${aoeSeoTemplate} \
      --target ${aoeSeoConfig} \
      --lock ${config.xdg.configHome}/agent-of-empires/profiles/seo/.config.lock

    $DRY_RUN_CMD ${lib.getExe reconciler} \
      --source ${aoeOwnTemplate} \
      --target ${aoeOwnConfig} \
      --lock ${config.xdg.configHome}/agent-of-empires/profiles/own/.config.lock
  '';
}
