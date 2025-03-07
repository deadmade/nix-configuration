{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  host,
  ...
}: {
  imports =
    [
      outputs.homeManagerModules.browser.floorp
      outputs.homeManagerModules.coding
      outputs.homeManagerModules.terminal
    ]
    ++ (builtins.attrValues outputs.homeManagerModules.core);

  home.packages = with pkgs; [
    pkgs.unstable.texlive.combined.scheme-full
  ];

  home.shellAliases = {
    nixC = "cd Documents/GitHub/nix-configuration";
  };
}
