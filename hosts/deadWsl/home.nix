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
        pkgs.unstable.texlive.combined.scheme-full
  ];
}
