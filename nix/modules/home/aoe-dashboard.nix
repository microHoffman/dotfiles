{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
let
  cfg = vars.aoeDashboard;
  environmentFile = "${config.xdg.configHome}/aoe-dashboard/serve.env";
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
  launcher = pkgs.writeShellApplication {
    name = "aoe-dashboard-launcher";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      if [ -z "''${AOE_SERVE_PASSPHRASE:-}" ]; then
        printf 'aoe-dashboard: AOE_SERVE_PASSPHRASE is missing or empty\n' >&2
        exit 1
      fi

      if command -v cloudflared >/dev/null 2>&1; then
        printf 'aoe-dashboard: refusing to start while cloudflared is on PATH; Tailscale Funnel must be the only public transport\n' >&2
        exit 1
      fi

      aoe_bin="''${AOE_BIN:-}"
      if [ -z "$aoe_bin" ]; then
        aoe_bin="$(command -v aoe || true)"
      fi
      if [ -z "$aoe_bin" ] || [ ! -x "$aoe_bin" ]; then
        printf 'aoe-dashboard: aoe is not installed or executable\n' >&2
        exit 1
      fi

      attempts=0
      status_json=""
      while [ "$attempts" -lt 60 ]; do
        if status_json="$(tailscale status --json --peers=false 2>/dev/null)" \
          && [ "$(printf '%s' "$status_json" | jq -r '.BackendState // empty')" = "Running" ]; then
          break
        fi
        attempts=$((attempts + 1))
        sleep 5
      done

      if [ -z "$status_json" ] \
        || [ "$(printf '%s' "$status_json" | jq -r '.BackendState // empty')" != "Running" ]; then
        printf 'aoe-dashboard: Tailscale did not reach BackendState=Running within five minutes\n' >&2
        exit 1
      fi

      if ! printf '%s' "$status_json" | jq -e '
        (.Self.CapMap // {} | keys)
        | any(startswith("https://tailscale.com/cap/funnel-ports"))
      ' >/dev/null; then
        printf 'aoe-dashboard: this node does not have the Tailscale Funnel capability\n' >&2
        exit 1
      fi

      exec "$aoe_bin" serve --remote --host 127.0.0.1 --port 8080
    '';
  };
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || cfg.enableTailscaleOperator;
          message = "aoeDashboard.enable requires aoeDashboard.enableTailscaleOperator approval";
        }
        {
          assertion = !cfg.enable || cfg.enableUserLinger;
          message = "aoeDashboard.enable requires aoeDashboard.enableUserLinger approval";
        }
      ];
    }

    (lib.mkIf cfg.enable {
      systemd.user.services.aoe-dashboard = {
        Unit = {
          Description = "Agent of Empires remote dashboard";
          After = [
            "network-online.target"
            "ssh-agent.service"
          ];
          Wants = [
            "network-online.target"
            "ssh-agent.service"
          ];
          ConditionPathExists = environmentFile;
        };

        Service = {
          Type = "simple";
          Environment = [
            "PATH=${servicePath}"
            "SSH_AUTH_SOCK=%t/ssh-agent"
            "XDG_CONFIG_HOME=${config.xdg.configHome}"
          ];
          EnvironmentFile = environmentFile;
          ExecStart = lib.getExe launcher;
          Restart = "on-failure";
          RestartSec = "30s";

          # AoE-managed tmux sessions intentionally outlive dashboard restarts.
          KillMode = "process";
        };

        Install.WantedBy = [ "default.target" ];
      };
    })
  ];
}
