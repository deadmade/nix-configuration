{
  outputs,
  pkgs,
  ...
}: {
  imports = [
    outputs.homeManagerModules.coding.direnv
    outputs.homeManagerModules.core.aliases
    outputs.homeManagerModules.core.homeConfig
    outputs.homeManagerModules.core.nixConfig

    outputs.homeManagerModules.terminal.fastfetch
    outputs.homeManagerModules.terminal.ghostty
    outputs.homeManagerModules.terminal.kitty
    outputs.homeManagerModules.terminal.nix-index
    outputs.homeManagerModules.terminal.starship
    outputs.homeManagerModules.terminal.tmux
    outputs.homeManagerModules.terminal.yazi
    outputs.homeManagerModules.terminal.zsh
  ];

  home.packages = with pkgs; [
  ];

  home.shellAliases = {
    nixC = "cd Documents/GitHub/nix-configuration";
    # tinfW = "cd 'Documents/GitHub/Tinf2023-LessonSummaries/DHBW Heidenheim'";
    updateNix = "nix flake update && sudo nixos-rebuild switch --flake .#deadWsl && home-manager switch --flake .#deadmade@deadWsl";
  };
}
