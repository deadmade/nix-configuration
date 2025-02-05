{ config, pkgs, ... }:
{

  # Add host-specific stuff
  home.packages = config.home.packages ++ (with pkgs; [
    vscode
  ]);
  home.stateVersion = "24.11";
}
