{ ... }:
{
  programs.mise = {
    enable = true;
    enableZshIntegration = true;

    globalConfig.settings = {
      all_compile = false;
    };
  };
}
