{vars, ...}: {
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = vars.gitUsername;
        email = vars.gitEmail;
      };
    };
  };

  programs.gh.enable = true;
}
