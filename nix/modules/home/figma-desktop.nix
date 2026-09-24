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
  figmaServices = [
    "figma-virtual-display.service"
    "figma-window-manager.service"
    "figma-desktop.service"
    "figma-vnc.service"
    "figma-novnc.service"
  ];
  figmaSession = pkgs.writeShellApplication {
    name = "figma-session";
    runtimeInputs = [
      pkgs.systemd
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      services_active() {
        for service in figma.target ${lib.concatStringsSep " " figmaServices}; do
          systemctl --user is-active --quiet "$service" || return 1
        done
      }

      mcp_ready() {
        curl -fsS --max-time "$1" \
          -H 'Accept: application/json, text/event-stream' \
          -H 'Content-Type: application/json' \
          --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"figma-session","version":"1.0"}}}' \
          http://127.0.0.1:${toString mcpPort}/mcp \
          | jq -e '.result.serverInfo.name == "figma-linux-next"' >/dev/null
      }

      if [ "$#" -ne 1 ]; then
        printf 'Usage: figma-session start|stop|status\n' >&2
        exit 2
      fi
      case "$1" in
        start)
          systemctl --user start --no-block figma.target
          deadline=$((SECONDS + 60))
          while [ "$SECONDS" -lt "$deadline" ]; do
            remaining=$((deadline - SECONDS))
            if services_active \
              && mcp_ready "$remaining" 2>/dev/null; then
              printf 'Figma is ready at http://127.0.0.1:${toString mcpPort}/mcp\n'
              exit 0
            fi
            sleep 1
          done
          printf 'Figma MCP was not ready within 60 seconds. Check figma-session status and journalctl --user -u figma-desktop.service.\n' >&2
          printf 'The desktop services remain available for login or troubleshooting through noVNC.\n' >&2
          exit 1
          ;;
        stop)
          systemctl --user stop figma.target ${lib.concatStringsSep " " figmaServices}
          printf 'Figma and its display/VNC services are stopped.\n'
          ;;
        status)
          systemctl --user --no-pager status figma.target ${lib.concatStringsSep " " figmaServices} || true
          if services_active && mcp_ready 5 2>/dev/null; then
            printf 'Figma MCP is ready.\n'
          else
            printf 'Figma MCP is stopped or not ready.\n'
            exit 1
          fi
          ;;
        *)
          printf 'Usage: figma-session start|stop|status\n' >&2
          exit 2
          ;;
      esac
    '';
  };
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
    home.packages = [ figmaSession ];
    systemd.user.targets.figma.Unit = {
      Description = "On-demand Figma desktop and graphical console";
      # A service restart must not stop the target and its other members.
      Wants = figmaServices;
      After = figmaServices;
    };
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
        Unit = {
          Description = "Authenticated virtual X11 display for Figma Linux";
          PartOf = [ "figma.target" ];
        };
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
      };

      figma-window-manager = {
        Unit = {
          Description = "Openbox window manager for the Figma virtual display";
          PartOf = [ "figma.target" ];
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
      };

      figma-desktop = {
        Unit = {
          Description = "On-demand Figma Linux desktop and local MCP server";
          PartOf = [ "figma.target" ];
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
      };

      figma-vnc = {
        Unit = {
          Description = "Authenticated loopback VNC for the Figma virtual display";
          PartOf = [ "figma.target" ];
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
          # x11vnc catches SIGTERM and exits 2 on a normal service stop.
          SuccessExitStatus = [ 2 ];
          Restart = "always";
          RestartSec = "5s";
        };
      };

      figma-novnc = {
        Unit = {
          Description = "Loopback browser console for the Figma virtual display";
          PartOf = [ "figma.target" ];
          After = [ "figma-vnc.service" ];
          Requires = [ "figma-vnc.service" ];
        };
        Service = {
          Type = "simple";
          # Supervise the server directly; novnc's shell launcher races with
          # SIGTERM during startup and can falsely report a failed shutdown.
          ExecStart = lib.concatStringsSep " " [
            (lib.getExe pkgs.python3Packages.websockify)
            "--file-only"
            "--web ${pkgs.novnc}/share/webapps/novnc"
            "127.0.0.1:${toString cfg.noVncPort}"
            "127.0.0.1:${toString cfg.vncPort}"
          ];
          Restart = "always";
          RestartSec = "5s";
        };
      };
    };
  };
}
