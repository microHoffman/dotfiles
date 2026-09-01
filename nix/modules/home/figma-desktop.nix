{
  config,
  inputs,
  lib,
  pkgs,
  vars,
  ...
}:
let
  cfg = vars.figmaDesktop;
  figmaPackage = inputs.figma-linux-next.packages.${pkgs.stdenv.hostPlatform.system}.default;
  mcpPort = 3845;
  stateDirectory = "${config.xdg.configHome}/figma-desktop";
  xAuthorityFile = "${stateDirectory}/Xauthority";
  vncPasswordFile = "${stateDirectory}/vnc-passwd";
  prepareRuntime = pkgs.writeShellApplication {
    name = "prepare-figma-desktop-runtime";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.openssl
      pkgs.xauth
    ];
    text = ''
      umask 077
      state_directory=${lib.escapeShellArg stateDirectory}
      xauthority_file=${lib.escapeShellArg xAuthorityFile}
      password_file="$state_directory/vnc-password"
      vnc_password_file=${lib.escapeShellArg vncPasswordFile}

      mkdir -p "$state_directory"

      if [ ! -s "$xauthority_file" ]; then
        cookie="$(openssl rand -hex 16)"
        xauth -f "$xauthority_file" add ${lib.escapeShellArg cfg.display} \
          MIT-MAGIC-COOKIE-1 "$cookie"
      fi

      if [ ! -s "$password_file" ]; then
        openssl rand -hex 4 >"$password_file"
      fi

      if [ ! -s "$vnc_password_file" ]; then
        ${lib.getExe' pkgs.tigervnc "vncpasswd"} -f \
          <"$password_file" >"$vnc_password_file"
      fi

      chmod 0600 "$xauthority_file" "$password_file" "$vnc_password_file"
    '';
  };
  waitForDisplay = pkgs.writeShellApplication {
    name = "wait-for-figma-display";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.xdpyinfo
    ];
    text = ''
      attempts=0
      until xdpyinfo -display ${lib.escapeShellArg cfg.display} >/dev/null 2>&1; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 60 ]; then
          printf 'figma-desktop: virtual display %s did not become ready\n' \
            ${lib.escapeShellArg cfg.display} >&2
          exit 1
        fi
        sleep 1
      done
    '';
  };
  figmaLauncher = pkgs.writeShellApplication {
    name = "figma-headless-launcher";
    runtimeInputs = [
      figmaPackage
      pkgs.dbus
      pkgs.xdg-utils
    ];
    text = ''
      ${lib.getExe waitForDisplay}
      exec dbus-run-session figma-linux-next \
        --use-gl=angle \
        --use-angle=swiftshader \
        --enable-unsafe-swiftshader
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix ":" cfg.display;
        message = "figmaDesktop.display must be an X display such as :99";
      }
      {
        assertion = cfg.vncPort != cfg.noVncPort && cfg.vncPort != mcpPort && cfg.noVncPort != mcpPort;
        message = "figmaDesktop VNC, noVNC, and MCP ports must not conflict";
      }
    ];

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
      };
    };

    systemd.user.services = {
      figma-virtual-display = {
        Unit.Description = "Authenticated virtual X11 display for Figma Linux";
        Service = {
          Type = "simple";
          ExecStartPre = lib.getExe prepareRuntime;
          ExecStart = lib.concatStringsSep " " [
            (lib.getExe' pkgs.xvfb "Xvfb")
            cfg.display
            "-screen 0 ${cfg.geometry}x24"
            "-nolisten tcp"
            "-noreset"
            "-auth ${xAuthorityFile}"
          ];
          Restart = "always";
          RestartSec = "5s";
        };
        Install.WantedBy = [ "default.target" ];
      };

      figma-window-manager = {
        Unit = {
          Description = "Openbox window manager for the Figma virtual display";
          After = [ "figma-virtual-display.service" ];
          Requires = [ "figma-virtual-display.service" ];
        };
        Service = {
          Type = "simple";
          Environment = [
            "DISPLAY=${cfg.display}"
            "XAUTHORITY=${xAuthorityFile}"
          ];
          ExecStartPre = lib.getExe waitForDisplay;
          ExecStart = "${pkgs.openbox}/bin/openbox";
          Restart = "always";
          RestartSec = "5s";
        };
        Install.WantedBy = [ "default.target" ];
      };

      figma-desktop = {
        Unit = {
          Description = "Always-on Figma Linux desktop and local MCP server";
          After = [
            "figma-virtual-display.service"
            "figma-window-manager.service"
            "network-online.target"
          ];
          Requires = [ "figma-virtual-display.service" ];
          Wants = [
            "figma-window-manager.service"
            "network-online.target"
          ];
        };
        Service = {
          Type = "simple";
          Environment = [
            "DISPLAY=${cfg.display}"
            "ELECTRON_OZONE_PLATFORM_HINT=x11"
            "GALLIUM_DRIVER=llvmpipe"
            "LIBGL_ALWAYS_SOFTWARE=1"
            "MESA_LOADER_DRIVER_OVERRIDE=llvmpipe"
            "XAUTHORITY=${xAuthorityFile}"
            "XDG_CURRENT_DESKTOP=Openbox"
          ];
          ExecStart = lib.getExe figmaLauncher;
          Restart = "always";
          RestartSec = "10s";
        };
        Install.WantedBy = [ "default.target" ];
      };

      figma-vnc = {
        Unit = {
          Description = "Authenticated loopback VNC for the Figma virtual display";
          After = [ "figma-virtual-display.service" ];
          Requires = [ "figma-virtual-display.service" ];
        };
        Service = {
          Type = "simple";
          Environment = [
            "DISPLAY=${cfg.display}"
            "XAUTHORITY=${xAuthorityFile}"
          ];
          ExecStartPre = lib.getExe waitForDisplay;
          ExecStart = lib.concatStringsSep " " [
            (lib.getExe pkgs.x11vnc)
            "-display ${cfg.display}"
            "-localhost"
            "-forever"
            "-shared"
            "-rfbauth ${vncPasswordFile}"
            "-rfbport ${toString cfg.vncPort}"
          ];
          Restart = "always";
          RestartSec = "5s";
        };
        Install.WantedBy = [ "default.target" ];
      };

      figma-novnc = {
        Unit = {
          Description = "Loopback browser console for the Figma virtual display";
          After = [ "figma-vnc.service" ];
          Requires = [ "figma-vnc.service" ];
        };
        Service = {
          Type = "simple";
          ExecStart = lib.concatStringsSep " " [
            (lib.getExe pkgs.novnc)
            "--listen 127.0.0.1:${toString cfg.noVncPort}"
            "--vnc 127.0.0.1:${toString cfg.vncPort}"
            "--file-only"
          ];
          Restart = "always";
          RestartSec = "5s";
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
  };
}
