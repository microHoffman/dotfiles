# Claude Code release pin

`release.json` is the official release manifest from
`https://downloads.claude.ai/claude-code-releases/2.1.291/manifest.json`.
Home Manager supplies it to Nixpkgs' existing Claude Code package, retaining
its NixOS library fixes and disabled self-updater. This updates Claude without
moving the whole Nixpkgs input. Authentication stays optional.

For a future update, fetch the official manifest for the chosen stable release,
review its version/checksums, run the flake checks and full system build, and
apply the rebuild. Do not use `claude update` for this Nix-managed package.
