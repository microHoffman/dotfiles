{
  config,
  lib,
  pkgs,
  ...
}:
let
  reconciler = pkgs.callPackage ../../packages/agent-config-reconciler.nix { };
  codexTemplate = ../../../setup/aoe-remote/codex-config.toml;
  aoeTemplate = ../../../setup/aoe-remote/aoe-config.toml;
  codexConfig = "${config.home.homeDirectory}/.codex/config.toml";
  aoeConfig = "${config.xdg.configHome}/agent-of-empires/config.toml";
in
{
  home.activation.reconcileAgentConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${lib.getExe reconciler} \
      --source ${codexTemplate} \
      --target ${codexConfig} \
      --lock ${codexConfig}.lock

    $DRY_RUN_CMD ${lib.getExe reconciler} \
      --source ${aoeTemplate} \
      --target ${aoeConfig} \
      --lock ${config.xdg.configHome}/agent-of-empires/.config.lock
  '';
}
