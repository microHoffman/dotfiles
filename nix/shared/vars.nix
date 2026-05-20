{
  username = "microhoffman";
  fullName = "microhoffman";
  homeDirectory = "/home/microhoffman";
  dotfilesDirectory = "/home/microhoffman/dotfiles";
  workDirectory = "/home/microhoffman/work";

  timeZone = "Asia/Bangkok";
  systemStateVersion = "25.11";
  homeStateVersion = "25.11";

  # netcup Root Servers usually expose the first virtio disk as /dev/vda.
  # Confirm with `lsblk` in rescue mode before running nixos-anywhere.
  installDisk = "/dev/vda";

  # Bootstrap mode. Set to false after normal OpenSSH over Tailscale works.
  allowPublicSsh = true;

  # Add your local client public SSH key before installation.
  # Example: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... laptop"
  authorizedSshKeys = [ ];

  git = {
    # Fill these in once you know the exact identity you want on the server.
    userName = null;
    userEmail = null;
  };
}
