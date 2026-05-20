{ vars, ... }:
let
  btrfsMountOptions = [
    "compress=zstd"
    "noatime"
  ];
in
{
  disko.devices.disk.main = {
    type = "disk";
    device = vars.installDisk;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "/root" = {
                mountpoint = "/";
                mountOptions = btrfsMountOptions;
              };
              "/home" = {
                mountpoint = "/home";
                mountOptions = btrfsMountOptions;
              };
              "/nix" = {
                mountpoint = "/nix";
                mountOptions = btrfsMountOptions;
              };
              "/var-log" = {
                mountpoint = "/var/log";
                mountOptions = btrfsMountOptions;
              };
            };
          };
        };
      };
    };
  };
}
