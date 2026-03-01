{
  outputs,
  pkgs,
  ...
}: {
  imports = [
    outputs.homeManagerProfiles.wsl
  ];

  home.packages = with pkgs; [
  ];

  home.shellAliases = {
    nixC = "cd Documents/GitHub/nix-configuration";
    # tinfW = "cd 'Documents/GitHub/Tinf2023-LessonSummaries/DHBW Heidenheim'";
    updateNix = "nix flake update && sudo nixos-rebuild switch --flake .#deadWsl && home-manager switch --flake .#deadmade@deadWsl";
  };
}
