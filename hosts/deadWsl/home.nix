{
  outputs,
  pkgs,
  ...
}: {
  imports =
    [
      #outputs.homeManagerModules.coding
      outputs.homeManagerModules.coding.direnv

      outputs.homeManagerModules.core.aliases
      outputs.homeManagerModules.core.home
      outputs.homeManagerModules.core.nixConfig
    ]
    ++ (builtins.attrValues outputs.homeManagerModules.terminal);

  home.packages = with pkgs; [
  ];

  home.shellAliases = {
    nixC = "cd Documents/GitHub/nix-configuration";
    # tinfW = "cd 'Documents/GitHub/Tinf2023-LessonSummaries/DHBW Heidenheim'";
    updateNix = "nix flake update && sudo nixos-rebuild switch --flake .#deadWsl && home-manager switch --flake .#deadmade@deadWsl";
  };
}
