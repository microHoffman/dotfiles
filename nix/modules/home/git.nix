{ lib, vars, ... }:
let
  hasUserName = vars.git.userName != null && vars.git.userName != "";
  hasUserEmail = vars.git.userEmail != null && vars.git.userEmail != "";
  userSettings = lib.optionalAttrs (hasUserName || hasUserEmail) {
    user =
      lib.optionalAttrs hasUserName {
        name = vars.git.userName;
      }
      // lib.optionalAttrs hasUserEmail {
        email = vars.git.userEmail;
      };
  };
in
{
  programs.git = {
    enable = true;
    settings = {
      alias = {
        co = "checkout";
        st = "status --short --branch";
        sw = "switch";
      };
      init.defaultBranch = "main";
      pull.ff = "only";
      push.autoSetupRemote = true;
      fetch.prune = true;
      rerere.enabled = true;
      core.editor = "nvim";
    }
    // userSettings;
  };
}
