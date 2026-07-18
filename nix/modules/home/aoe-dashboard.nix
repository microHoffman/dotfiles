{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
let
  cfg = vars.aoeDashboard;
  environmentFile = "${vars.homeDirectory}/.config/aoe-dashboard/serve.env";
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
      pkgs.tmux
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

      # Current AoE releases recover missing tmux sessions when `aoe serve`
      # starts. On the first dashboard start of each host boot, archive only
      # sessions without a live tmux pane so reboot recovery remains an
      # explicit operator action. Archive is an official, reversible AoE
      # state transition and preserves the worktree, branch, and transcript.
      state_dir="''${XDG_STATE_HOME:-''${HOME}/.local/state}/aoe-dashboard"
      boot_marker="$state_dir/last-dashboard-boot-id"
      current_boot_id="$(tr -d '\n' </proc/sys/kernel/random/boot_id)"
      if [ -z "$current_boot_id" ]; then
        printf 'aoe-dashboard: could not read the current host boot id\n' >&2
        exit 1
      fi
      previous_boot_id=""
      if [ -r "$boot_marker" ]; then
        previous_boot_id="$(tr -d '\n' <"$boot_marker")"
      fi

      if [ "$current_boot_id" != "$previous_boot_id" ]; then
        tmux_names="$(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)"
        sessions_json="$("$aoe_bin" list --all --json)"
        archived_count=0

        while IFS=$'\t' read -r profile session_id; do
          if [ -z "$profile" ] || [ -z "$session_id" ]; then
            printf 'aoe-dashboard: invalid session metadata while preparing reboot recovery\n' >&2
            exit 1
          fi

          short_id="''${session_id:0:8}"
          case "$short_id" in
            *[!A-Za-z0-9-]*)
              printf 'aoe-dashboard: refusing unsafe session id while preparing reboot recovery\n' >&2
              exit 1
              ;;
          esac

          has_live_tmux=false
          while IFS= read -r tmux_name; do
            case "$tmux_name" in
              aoe_*_"$short_id")
                has_live_tmux=true
                break
                ;;
            esac
          done <<<"$tmux_names"

          if [ "$has_live_tmux" = false ]; then
            "$aoe_bin" session archive --no-kill --profile "$profile" "$session_id" >/dev/null
            archived_count=$((archived_count + 1))
          fi
        done < <(printf '%s' "$sessions_json" | jq -r '.[] | [.profile, .id] | @tsv')

        install -d -m 700 -- "$state_dir"
        temporary_marker="$(mktemp "$state_dir/.last-dashboard-boot-id.XXXXXX")"
        chmod 600 "$temporary_marker"
        printf '%s\n' "$current_boot_id" >"$temporary_marker"
        mv -- "$temporary_marker" "$boot_marker"
        printf 'aoe-dashboard: quarantined %s non-running session(s) for deliberate post-reboot recovery\n' "$archived_count"
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
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
          ConditionPathExists = environmentFile;
        };

        Service = {
          Type = "simple";
          Environment = [ "PATH=${servicePath}" ];
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
