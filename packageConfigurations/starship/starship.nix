{
  # Install & Configure Starship
  programs.starship = {
    enable = true;
    settings = pkgs.lib.importTOML ../../packageConfigurations/starship/starship.toml;
    enableZshIntegration = true;
  };
}