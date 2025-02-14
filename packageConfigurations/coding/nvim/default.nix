{inputs, ...}: {
  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    ./plugins.nix
  ];

  programs.nixvim.enable = true;
}
