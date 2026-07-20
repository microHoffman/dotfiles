{
  username = "microhoffman";
  fullName = "microhoffman";
  homeDirectory = "/home/microhoffman";
  dotfilesDirectory = "/home/microhoffman/dotfiles";
  workDirectory = "/home/microhoffman/work";

  timeZone = "Europe/Prague";

  # Initial-install compatibility baselines. Do not bump these during routine
  # upgrades after this host has been deployed.
  systemStateVersion = "26.05";
  homeStateVersion = "26.05";

  # netcup Root Servers usually expose the first virtio disk as /dev/vda.
  # Confirm with `lsblk` in rescue mode before running nixos-anywhere.
  installDisk = "/dev/vda";

  # Normal OpenSSH is reachable only over Tailscale after bootstrap.
  allowPublicSsh = false;

  # These stay false until their separate runtime approval gates are complete.
  # Enabling the dashboard requires both operator access and user lingering.
  aoeDashboard = {
    enable = true;
    enableTailscaleOperator = true;
    enableUserLinger = true;
  };

  # Add your local client public SSH key before installation.
  # Example: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... laptop"
  authorizedSshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF1RNTrzQEnZxEHoF9Rx+ZGdV1HvwwaiIcT+0Tkducki skozak@protonmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGb9Eijgi5eiL4UFrCqoUQ0QLpf4YbxuKlt3A0pSWEGs android-termux-remote-dev"
  ];

  git = {
    userName = "microHoffman";
    userEmail = "skozak@protonmail.com";
  };
}
