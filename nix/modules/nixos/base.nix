{ ... }:
{
  documentation.man.enable = true;

  security.rtkit.enable = false;

  services.journald.extraConfig = ''
    SystemMaxUse=1G
    RuntimeMaxUse=256M
  '';
}
