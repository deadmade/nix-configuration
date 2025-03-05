{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  host,
  ...
}: {
  imports = [
    outputs.homeManagerModules.defaultConfig
    outputs.homeManagerModules.browser
    outputs.homeManagerModules.coding
    outputs.homeManagerModules.terminal
    outputs.homeManagerModules.hyprland
  ];

  home.packages = with pkgs; [
    pkgs.unstable.texlive.combined.scheme-full
  ];
}
