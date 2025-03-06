{vars, ...}: {
  # # Install & Configure Git
  programs.git = {
    enable = true;
    userName = vars.gitUsername;
    userEmail = vars.gitEmail;
  };

  # Install & Configure GitHub CLI
  programs.gh.enable = true;
}
