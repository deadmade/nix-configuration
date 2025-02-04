{ config, pkgs, ... }:
{

  # Add host-specific stuff
  home.packages = config.home.packages ++ (with pkgs; [
    vscode
  ]);
}
