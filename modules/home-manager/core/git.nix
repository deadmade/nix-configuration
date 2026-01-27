{vars, ...}: {
  # # Install & Configure Git
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

  # Install & Configure GitHub CLI
  programs.gh.enable = true;
}
