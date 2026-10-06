{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
let
  cfg = vars.orcaRuntime;
  stateDirectory = "${config.xdg.configHome}/orca-runtime";
  xAuthorityFile = "${stateDirectory}/Xauthority";
  appDirectory = "${config.xdg.dataHome}/orca-install/current";
  servicePath = lib.concatStringsSep ":" [
    "${vars.homeDirectory}/.local/bin"
    "${vars.homeDirectory}/.cargo/bin"
    "${vars.homeDirectory}/.bun/bin"
    "${vars.homeDirectory}/.local/share/mise/shims"
    "${config.home.profileDirectory}/bin"
    "/run/current-system/sw/bin"
    "/usr/bin"
    "/bin"
  ];
  prepareDisplay = pkgs.writeShellApplication {
    name = "prepare-orca-display";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.openssl
      pkgs.xauth
    ];
    text = ''
      umask 077
      mkdir -p ${lib.escapeShellArg stateDirectory}
      if [ ! -s ${lib.escapeShellArg xAuthorityFile} ]; then
        xauth -f ${lib.escapeShellArg xAuthorityFile} add ${lib.escapeShellArg cfg.display} \
          MIT-MAGIC-COOKIE-1 "$(openssl rand -hex 16)"
      fi
      chmod 0700 ${lib.escapeShellArg stateDirectory}
      chmod 0600 ${lib.escapeShellArg xAuthorityFile}
    '';
  };
  launcher = pkgs.writeShellApplication {
    name = "orca-runtime-launcher";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.iproute2
      pkgs.util-linux
      pkgs.xdpyinfo
    ];
    text = builtins.readFile ../../../setup/orca/serve.sh;
  };
in
{
  config = lib.mkIf cfg.enable {
    # Authentication is optional. The package alone makes Claude ready for later use.
    home.packages = [
      (pkgs.claude-code.override {
        manifest = lib.importJSON ../../../setup/claude-code/release.json;
      })
    ];

    assertions = [
      {
        assertion = builtins.match ":[0-9]+" cfg.display != null;
        message = "orcaRuntime.display must be an X display such as :100";
      }
      {
        assertion = !vars.figmaDesktop.enable || cfg.display != vars.figmaDesktop.display;
        message = "Orca and Figma require separate X displays";
      }
      {
        assertion = cfg.port > 0 && cfg.port <= 65535 && cfg.port != vars.aoeDashboard.port;
        message = "orcaRuntime.port must be valid and distinct from the AoE dashboard port";
      }
    ];

    systemd.user.services = {
      orca-virtual-display = {
        Unit = {
          Description = "Authenticated virtual X11 display for Orca";
          PartOf = [ "orca-runtime.service" ];
        };
        Service = {
          Type = "simple";
          ExecStartPre = lib.getExe prepareDisplay;
          ExecStart = "${pkgs.xvfb}/bin/Xvfb ${cfg.display} -screen 0 1920x1080x24 -nolisten tcp -noreset -auth ${xAuthorityFile}";
          Restart = "on-failure";
          RestartSec = "5s";
          UMask = "0077";
        };
      };

      orca-runtime = {
        Unit = {
          Description = "Orca private remote development runtime";
          After = [
            "orca-virtual-display.service"
            "ssh-agent.service"
          ];
          Requires = [ "orca-virtual-display.service" ];
          Wants = [ "ssh-agent.service" ];
          ConditionFileIsExecutable = "${appDirectory}/AppRun";
          StartLimitIntervalSec = 300;
          StartLimitBurst = 5;
        };
        Service = {
          Type = "simple";
          WorkingDirectory = vars.homeDirectory;
          Environment = [
            "PATH=${servicePath}"
            "DISPLAY=${cfg.display}"
            "XAUTHORITY=${xAuthorityFile}"
            "XDG_CONFIG_HOME=${config.xdg.configHome}"
            "XDG_DATA_HOME=${config.xdg.dataHome}"
            "NIX_LD=/run/current-system/sw/share/nix-ld/lib/ld.so"
            "NIX_LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib"
            "SSH_AUTH_SOCK=%t/ssh-agent"
            "LIBGL_ALWAYS_SOFTWARE=1"
            "ELECTRON_OZONE_PLATFORM_HINT=x11"
            "ORCA_TELEMETRY_DISABLED=1"
            "ORCA_APP_DIR=${appDirectory}"
            "ORCA_PORT=${toString cfg.port}"
          ];
          ExecStart = lib.getExe launcher;
          Restart = "on-failure";
          RestartPreventExitStatus = [ 3 ];
          RestartSec = "15s";
          TimeoutStopSec = "30s";
          # Orca places its terminal daemon in a separate systemd user scope.
          KillMode = "mixed";
          UMask = "0077";
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
  };
}
