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
  ];

  home.packages = with pkgs; [
  ];
}
