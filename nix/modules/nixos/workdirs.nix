{ vars, ... }:
{
  systemd.tmpfiles.rules = [
    "d ${vars.dotfilesDirectory} 0755 ${vars.username} users -"
    "d ${vars.workDirectory} 0755 ${vars.username} users -"
    "d ${vars.workDirectory}/companies 0755 ${vars.username} users -"
    "d ${vars.workDirectory}/personal 0755 ${vars.username} users -"
    "d ${vars.workDirectory}/scratch 0755 ${vars.username} users -"
  ];
}
