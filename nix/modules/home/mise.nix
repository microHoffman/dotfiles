{ ... }:
{
  programs.mise = {
    enable = true;
    enableZshIntegration = true;

    globalConfig = {
      settings = {
        all_compile = false;
      };

      tools."github:microHoffman/activecollab-cli" = "0.3.0";
    };
  };
}
