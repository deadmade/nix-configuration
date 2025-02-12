{
  # Install & Configure Starship
  programs.starship = {
    enable = true;
    settings = pkgs.lib.importTOML ./starship.toml;
    enableZshIntegration = true;
  };
}
