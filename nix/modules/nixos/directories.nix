{ vars, ... }:
{
  systemd.tmpfiles.rules = [
    "d ${vars.dotfilesDirectory} 0755 ${vars.username} users -"
  ];
}
