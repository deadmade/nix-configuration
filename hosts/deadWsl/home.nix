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
      #outputs.homeManagerModules.coding
      outputs.homeManagerModules.terminal
    ]
    ++ (builtins.attrValues outputs.homeManagerModules.core);

  home.packages = with pkgs; [
  ];

  home.shellAliases = {
    nixC = "cd Documents/GitHub/nix-configuration";
    tinf = "cd 'Documents/GitHub/Tinf2023-LessonSummaries/DHBW Heidenheim'";
    updateNix = "nix flake update && sudo nixos-rebuild switch --flake .#deadWsl && home-manager switch --flake .#deadmade@deadWsl";
  };
}
