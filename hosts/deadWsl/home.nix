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
  ];

  home.packages = with pkgs; [
    remnote
    pkgs.unstable.texlive.combined.scheme-full
  ];
}
