{ config, pkgs, ... }:

let
  defaultConfig = import ../../default/home.nix { inherit pkgs; };
in
{
  imports = [ defaultConfig ];

  # Add host-specific overrides
  home.packages = defaultConfig.home.packages ++ (with pkgs; [
    vscode # Only on this specific host
  ]);
}
