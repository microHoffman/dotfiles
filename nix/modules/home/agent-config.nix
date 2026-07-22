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
  codexSentryTemplate = ../../../setup/aoe-remote/sentry.config.toml;
  aoeTemplate = ../../../setup/aoe-remote/aoe-config.toml;
  aoeSeoTemplate = ../../../setup/aoe-remote/profiles/seo/config.toml;
  aoeOwnTemplate = ../../../setup/aoe-remote/profiles/own/config.toml;
  aoeSentryTemplate = ../../../setup/aoe-remote/profiles/sentry/config.toml;
  codexConfig = "${config.home.homeDirectory}/.codex/config.toml";
  codexSeoConfig = "${config.home.homeDirectory}/.codex/seo.config.toml";
  codexOwnConfig = "${config.home.homeDirectory}/.codex/own.config.toml";
  codexSentryConfig = "${config.home.homeDirectory}/.codex/sentry.config.toml";
  aoeConfig = "${config.xdg.configHome}/agent-of-empires/config.toml";
  aoeSeoConfig = "${config.xdg.configHome}/agent-of-empires/profiles/seo/config.toml";
  aoeOwnConfig = "${config.xdg.configHome}/agent-of-empires/profiles/own/config.toml";
  aoeSentryConfig = "${config.xdg.configHome}/agent-of-empires/profiles/sentry/config.toml";
  legacySentryMcp = ''{ url = "https://mcp.sentry.dev/mcp?skills=inspect", enabled = true }'';
  managedAgentConfigs = pkgs.writeShellApplication {
    name = "reconcile-managed-agent-configs";
    runtimeInputs = [ reconciler ];
    text = ''
      reconcile-agent-config \
        --source ${codexTemplate} \
        --target ${codexConfig} \
        --lock ${codexConfig}.lock \
        --delete-if-equals mcp_servers.sentry ${lib.escapeShellArg legacySentryMcp}

      reconcile-agent-config \
        --source ${codexSeoTemplate} \
        --target ${codexSeoConfig} \
        --lock ${codexSeoConfig}.lock

      reconcile-agent-config \
        --source ${codexOwnTemplate} \
        --target ${codexOwnConfig} \
        --lock ${codexOwnConfig}.lock

      reconcile-agent-config \
        --source ${codexSentryTemplate} \
        --target ${codexSentryConfig} \
        --lock ${codexSentryConfig}.lock

      reconcile-agent-config \
        --source ${aoeTemplate} \
        --target ${aoeConfig} \
        --lock ${config.xdg.configHome}/agent-of-empires/.config.lock \
        --delete-if-equals session.custom_agents.codex-sentry \
          ${lib.escapeShellArg ''"codex --config mcp_servers.sentry.enabled=true"''} \
        --delete-if-equals session.agent_detect_as.codex-sentry \
          ${lib.escapeShellArg ''"codex"''}

      reconcile-agent-config \
        --source ${aoeSeoTemplate} \
        --target ${aoeSeoConfig} \
        --lock ${config.xdg.configHome}/agent-of-empires/profiles/seo/.config.lock

      reconcile-agent-config \
        --source ${aoeOwnTemplate} \
        --target ${aoeOwnConfig} \
        --lock ${config.xdg.configHome}/agent-of-empires/profiles/own/.config.lock

      reconcile-agent-config \
        --source ${aoeSentryTemplate} \
        --target ${aoeSentryConfig} \
        --lock ${config.xdg.configHome}/agent-of-empires/profiles/sentry/.config.lock
    '';
  };
in
{
  home.packages = [ managedAgentConfigs ];

  home.file.".codex/AGENTS.md" = {
    source = ../../../setup/agent-config/AGENTS.md;
    force = true;
  };

  xdg.configFile."agent-of-empires/profiles/sentry/mcp.json" = {
    source = ../../../setup/aoe-remote/profiles/sentry/mcp.json;
    force = true;
  };

  home.activation.reconcileAgentConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${lib.getExe managedAgentConfigs}
  '';
}
