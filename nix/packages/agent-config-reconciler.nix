{
  python3Packages,
  writers,
}:
writers.writePython3Bin "reconcile-agent-config" {
  libraries = [ python3Packages.tomlkit ];
} (builtins.readFile ../../setup/aoe-remote/reconcile_config.py)
